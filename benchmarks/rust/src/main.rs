//! Rust binding benchmark for #86 — binding-layer overhead measurement.
//!
//! Drives the graphqlite Rust binding through a fixed set of operations against a
//! fresh in-memory graph, timing each op with `std::time::Instant`. Emits a
//! single JSON document on stdout so `benchmarks/run.sh` can collect it alongside
//! the Python and TS legs.
//!
//! IMPORTANT: all three language benchmarks share the *same* C core
//! (`src/extension.c`) via the same staged dylib (`GRAPHQLITE_EXTENSION_PATH`).
//! These numbers are NOT core algorithm speed — they measure per-binding overhead
//! (bulk-insert strategy, value marshalling, per-call round-trips, result
//! parsing) layered on top of that shared core.
//!
//! Built with `--no-default-features` so the binding loads the env dylib instead
//! of its embedded extension. Ops: build / lookup / scan / pagerank / bfs, each
//! with 1 discarded warm-up run + `--repeats` measured runs on a fresh
//! `:memory:` graph.
//!
//!   cargo run --release --no-default-features -- \
//!       [--nodes 5000] [--edges 10000] [--repeats 3] [--lookups 2000]

use std::time::Instant;

use graphqlite::{graph, Graph, PropertyValue};
use serde_json::{json, Value};

// Deterministic dataset multiplier — shared across the Python/TS/Rust runners so
// every binding builds the byte-identical graph.
const EDGE_K: usize = 3;

type NodeItem = (String, Vec<(String, PropertyValue)>, String);
type EdgeItem = (String, String, Vec<(String, PropertyValue)>, String);

struct Params {
    nodes: usize,
    edges: usize,
    repeats: usize,
    lookups: usize,
}

fn parse_args() -> Params {
    let mut p = Params {
        nodes: 5000,
        edges: 10000,
        repeats: 3,
        lookups: 2000,
    };
    let argv: Vec<String> = std::env::args().skip(1).collect();
    let mut i = 0;
    while i < argv.len() {
        let val = argv.get(i + 1).and_then(|s| s.parse::<usize>().ok());
        match argv[i].as_str() {
            "--nodes" => {
                if let Some(v) = val {
                    p.nodes = v;
                    i += 1;
                }
            }
            "--edges" => {
                if let Some(v) = val {
                    p.edges = v;
                    i += 1;
                }
            }
            "--repeats" => {
                if let Some(v) = val {
                    p.repeats = v;
                    i += 1;
                }
            }
            "--lookups" => {
                if let Some(v) = val {
                    p.lookups = v;
                    i += 1;
                }
            }
            _ => {}
        }
        i += 1;
    }
    p
}

/// Deterministic (index-seeded) node/edge lists, identical across bindings:
///   node id = "n{i}", props = {"val": i} (int), label "N"
///   edge  i = ("n{i%N}" -> "n{(i*K+1)%N}"), rel "E", no props
fn build_dataset(n_nodes: usize, n_edges: usize) -> (Vec<NodeItem>, Vec<EdgeItem>) {
    let nodes: Vec<NodeItem> = (0..n_nodes)
        .map(|i| {
            (
                format!("n{i}"),
                vec![("val".to_string(), PropertyValue::Integer(i as i64))],
                "N".to_string(),
            )
        })
        .collect();
    let edges: Vec<EdgeItem> = (0..n_edges)
        .map(|i| {
            (
                format!("n{}", i % n_nodes),
                format!("n{}", (i * EDGE_K + 1) % n_nodes),
                Vec::new(),
                "E".to_string(),
            )
        })
        .collect();
    (nodes, edges)
}

fn median(mut v: Vec<f64>) -> f64 {
    v.sort_by(|a, b| a.partial_cmp(b).unwrap());
    let n = v.len();
    if n == 0 {
        return 0.0;
    }
    if n % 2 == 0 {
        (v[n / 2 - 1] + v[n / 2]) / 2.0
    } else {
        v[n / 2]
    }
}

fn round4(x: f64) -> f64 {
    (x * 1e4).round() / 1e4
}

/// Run `setup` (untimed) then time `run` for 1 warm-up + `repeats` runs. `run`
/// returns a "count" (result size / op count) used as a cross-language sanity
/// check. The warm-up run (r == 0) is discarded.
fn measure<S, R, T>(name: &str, repeats: usize, setup: S, run: R, teardown: T) -> Value
where
    S: Fn() -> Graph,
    R: Fn(&Graph) -> usize,
    T: Fn(Graph),
{
    let mut times_ms: Vec<f64> = Vec::with_capacity(repeats);
    let mut count = 0usize;
    for r in 0..=repeats {
        let g = setup();
        let t0 = Instant::now();
        count = run(&g);
        let elapsed = t0.elapsed();
        teardown(g);
        if r > 0 {
            times_ms.push(elapsed.as_secs_f64() * 1000.0);
        }
    }
    let runs = times_ms.len();
    let min_ms = times_ms.iter().cloned().fold(f64::INFINITY, f64::min);
    json!({
        "name": name,
        "ms_median": round4(median(times_ms)),
        "ms_min": round4(min_ms),
        "runs": runs,
        "count": count,
    })
}

fn main() {
    let p = parse_args();
    let (nodes, edges) = build_dataset(p.nodes, p.edges);
    let lookup_ids: Vec<String> = (0..p.lookups).map(|i| format!("n{}", i % p.nodes)).collect();
    let seed = "n0";

    let fresh = || graph(":memory:").expect("open in-memory graph");
    let loaded = || {
        let g = graph(":memory:").expect("open in-memory graph");
        g.insert_graph_bulk(nodes.clone(), edges.clone())
            .expect("bulk insert");
        g
    };
    let close = |g: Graph| drop(g);

    let mut ops: Vec<Value> = Vec::new();

    // build — bulk insert path (fresh empty graph, time only the insert)
    ops.push(measure(
        "build",
        p.repeats,
        &fresh,
        |g| {
            g.insert_graph_bulk(nodes.clone(), edges.clone())
                .expect("bulk insert")
                .nodes_inserted
        },
        &close,
    ));

    // lookup — L individual get_node round-trips (total time)
    ops.push(measure(
        "lookup",
        p.repeats,
        &loaded,
        |g| {
            let mut hits = 0usize;
            for id in &lookup_ids {
                if g.get_node(id).expect("get_node").is_some() {
                    hits += 1;
                }
            }
            hits
        },
        &close,
    ));

    // scan — full result marshalling (query + materialize every cell to an owned
    // serde_json Value, mirroring the TS toList()/Python list[dict] marshalling).
    ops.push(measure(
        "scan",
        p.repeats,
        &loaded,
        |g| {
            let res = g.query("MATCH (n) RETURN n.id").expect("scan query");
            let mut marshalled: Vec<Value> = Vec::with_capacity(res.len());
            for row in res.iter() {
                for col in row.columns() {
                    let v = row
                        .get_value(col)
                        .map(|val| serde_json::to_value(val).unwrap_or(Value::Null))
                        .unwrap_or(Value::Null);
                    marshalled.push(v);
                }
            }
            marshalled.len()
        },
        &close,
    ));

    // pagerank
    ops.push(measure(
        "pagerank",
        p.repeats,
        &loaded,
        |g| g.pagerank(0.85, 20).expect("pagerank").len(),
        &close,
    ));

    // bfs
    ops.push(measure(
        "bfs",
        p.repeats,
        &loaded,
        |g| g.bfs(seed, None).expect("bfs").len(),
        &close,
    ));

    let out = json!({
        "binding": "rust",
        "env": {
            // rustc/cargo versions are captured by run.sh (the binary can't see
            // the toolchain version without a build script); here we report the
            // build profile and target that ARE compiled in.
            "profile": if cfg!(debug_assertions) { "debug" } else { "release" },
            "target": std::env::consts::ARCH,
            "os": std::env::consts::OS,
        },
        "params": {
            "nodes": p.nodes,
            "edges": p.edges,
            "repeats": p.repeats,
            "lookups": p.lookups,
        },
        "ops": ops,
    });

    println!("{}", serde_json::to_string(&out).expect("serialize output"));
}
