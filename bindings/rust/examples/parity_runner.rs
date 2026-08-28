//! Rust parity runner for #84 — adds the Rust leg to the #30 [V-01] harness.
//!
//! Loads the shared `scenarios.json`, executes every scenario against a fresh
//! in-memory graph built from the shared `fixture`, and emits one JSON document
//! on stdout describing each step's outcome — mirroring `run-ts.ts` /
//! `run_python.py` exactly so `compare.py` can diff all three bindings.
//!
//! Two modes:
//!
//!   results (default): record each step's return value (or the error it raised).
//!   cypher           : record the ordered list of Cypher query strings (+ params)
//!                      the binding emits to the core while running the step.
//!                      Captured via the off-by-default `parity-spy` feature which
//!                      records inside `Connection::cypher` /
//!                      `execute_cypher_with_params` (the two points every
//!                      node/edge/query/algorithm method funnels through). Steps
//!                      that throw before hitting the core, or that use raw SQL
//!                      (bulk inserts), emit an empty/partial call list.
//!
//! This runner drives only the public Rust `Graph`/`Connection` API. The
//! extension is resolved by the binding itself (`GRAPHQLITE_EXTENSION_PATH` is
//! honored under `--no-default-features`). Usage:
//!
//!   cargo run --example parity_runner --no-default-features --features parity-spy \
//!       -- [--mode results|cypher] [--scenarios PATH]

use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;

use graphqlite::{graph, CypherResult, Error, Graph, PropertyValue};
use serde::Serialize;
use serde_json::{json, Map, Value};

#[derive(Clone, Copy, PartialEq, Eq)]
enum Mode {
    Results,
    Cypher,
}

/// An error surfaced by a step, mirroring the TS/Python `{type, message}` shape.
struct StepError {
    err_type: String,
    message: String,
}

fn err_type_name(e: &Error) -> &'static str {
    match e {
        Error::Sqlite(_) => "Sqlite",
        Error::Json(_) => "Json",
        Error::Cypher(_) => "Cypher",
        Error::ExtensionNotFound(_) => "ExtensionNotFound",
        Error::TypeError { .. } => "TypeError",
        Error::ColumnNotFound(_) => "ColumnNotFound",
        Error::GraphExists(_) => "GraphExists",
        Error::GraphNotFound { .. } => "GraphNotFound",
        Error::Io(_) => "Io",
    }
}

fn to_step_err(e: Error) -> StepError {
    StepError {
        err_type: err_type_name(&e).to_string(),
        message: e.to_string(),
    }
}

/// A method that exists in the shared scenarios but has no Rust binding.
fn unsupported(method: &str) -> StepError {
    StepError {
        err_type: "UnsupportedOperation".to_string(),
        message: format!("{method} is not available in the Rust binding."),
    }
}

// ── Value coercion helpers ─────────────────────────────────────────────────────

/// Serialize any binding return value into a `serde_json::Value`.
fn map_res<T: Serialize>(r: Result<T, Error>) -> Result<Value, StepError> {
    r.map(|v| serde_json::to_value(v).unwrap_or(Value::Null))
        .map_err(to_step_err)
}

/// Convert a `CypherResult` into an array of row objects (column -> value), so
/// its JSON shape matches the Python/TS runners.
fn cypher_result_to_json(res: &CypherResult) -> Value {
    let mut rows = Vec::with_capacity(res.len());
    for row in res.iter() {
        let mut obj = Map::new();
        for col in row.columns() {
            let v = row
                .get_value(col)
                .map(|val| serde_json::to_value(val).unwrap_or(Value::Null))
                .unwrap_or(Value::Null);
            obj.insert(col.clone(), v);
        }
        rows.push(Value::Object(obj));
    }
    Value::Array(rows)
}

fn map_cypher(r: Result<CypherResult, Error>) -> Result<Value, StepError> {
    r.map(|res| cypher_result_to_json(&res)).map_err(to_step_err)
}

/// Convert a JSON property value into a typed `PropertyValue`. Numbers keep the
/// int/float distinction serde_json parsed (so `1.0` stays a float, matching a
/// Python caller and — via the typed-table routing — diverging from JS, exactly
/// like the bulk quirk the harness pins).
fn json_to_prop(v: &Value) -> PropertyValue {
    match v {
        Value::Bool(b) => PropertyValue::Bool(*b),
        Value::Number(n) => {
            if let Some(i) = n.as_i64() {
                PropertyValue::Integer(i)
            } else if let Some(f) = n.as_f64() {
                PropertyValue::Float(f)
            } else {
                PropertyValue::Text(n.to_string())
            }
        }
        Value::String(s) => PropertyValue::Text(s.clone()),
        _ => PropertyValue::Text(v.to_string()),
    }
}

/// Turn a JSON object argument into an ordered `(key, PropertyValue)` list.
fn props_of(v: &Value) -> Vec<(String, PropertyValue)> {
    match v.as_object() {
        Some(map) => map
            .iter()
            .map(|(k, val)| (k.clone(), json_to_prop(val)))
            .collect(),
        None => Vec::new(),
    }
}

// ── Positional argument accessors ──────────────────────────────────────────────

fn str_arg(args: &[Value], i: usize) -> &str {
    args.get(i).and_then(Value::as_str).unwrap_or("")
}

fn opt_str_arg(args: &[Value], i: usize) -> Option<&str> {
    args.get(i).and_then(Value::as_str)
}

fn opt_i32_arg(args: &[Value], i: usize) -> Option<i32> {
    args.get(i).and_then(Value::as_i64).map(|x| x as i32)
}

fn opt_f64_arg(args: &[Value], i: usize) -> Option<f64> {
    args.get(i).and_then(Value::as_f64)
}

// ── Bulk item builders ─────────────────────────────────────────────────────────

type NodeItem = (String, Vec<(String, PropertyValue)>, String);
type EdgeItem = (String, String, Vec<(String, PropertyValue)>, String);

fn build_nodes(v: Option<&Value>) -> Vec<NodeItem> {
    let arr = match v.and_then(Value::as_array) {
        Some(a) => a,
        None => return Vec::new(),
    };
    arr.iter()
        .filter_map(Value::as_array)
        .map(|t| {
            let id = t.first().and_then(Value::as_str).unwrap_or("").to_string();
            let props = t.get(1).map(props_of).unwrap_or_default();
            let label = t.get(2).and_then(Value::as_str).unwrap_or("").to_string();
            (id, props, label)
        })
        .collect()
}

fn build_edges(v: Option<&Value>) -> Vec<EdgeItem> {
    let arr = match v.and_then(Value::as_array) {
        Some(a) => a,
        None => return Vec::new(),
    };
    arr.iter()
        .filter_map(Value::as_array)
        .map(|t| {
            let src = t.first().and_then(Value::as_str).unwrap_or("").to_string();
            let tgt = t.get(1).and_then(Value::as_str).unwrap_or("").to_string();
            let props = t.get(2).map(props_of).unwrap_or_default();
            let rel = t.get(3).and_then(Value::as_str).unwrap_or("").to_string();
            (src, tgt, props, rel)
        })
        .collect()
}

fn build_id_map(v: Option<&Value>) -> HashMap<String, i64> {
    let mut m = HashMap::new();
    if let Some(obj) = v.and_then(Value::as_object) {
        for (k, val) in obj {
            if let Some(i) = val.as_i64() {
                m.insert(k.clone(), i);
            }
        }
    }
    m
}

/// Report which typed table (int/real/text/bool) a node property landed in.
/// Raw SQL via the driver escape hatch — the Rust twin of run-ts.ts `propTableOf`.
/// This surfaces the intentional float→table divergence without changing any
/// method's return value. Emits no Cypher, so cypher-mode captures stay empty.
fn bulk_prop_table(g: &Graph, external_id: &str, key: &str) -> Value {
    let conn = g.connection().sqlite_connection();

    let id_key_id: Option<i64> = conn
        .query_row("SELECT id FROM property_keys WHERE key = 'id'", [], |r| {
            r.get(0)
        })
        .ok();
    let id_key_id = match id_key_id {
        Some(x) => x,
        None => return Value::Null,
    };

    let node_id: Option<i64> = conn
        .query_row(
            "SELECT node_id FROM node_props_text WHERE key_id = ? AND value = ?",
            rusqlite::params![id_key_id, external_id],
            |r| r.get(0),
        )
        .ok();
    let node_id = match node_id {
        Some(x) => x,
        None => return Value::Null,
    };

    let key_id: Option<i64> = conn
        .query_row(
            "SELECT id FROM property_keys WHERE key = ?",
            rusqlite::params![key],
            |r| r.get(0),
        )
        .ok();
    let key_id = match key_id {
        Some(x) => x,
        None => return Value::Null,
    };

    for suffix in ["int", "real", "text", "bool"] {
        let found: Option<i64> = conn
            .query_row(
                &format!("SELECT 1 FROM node_props_{suffix} WHERE node_id = ? AND key_id = ?"),
                rusqlite::params![node_id, key_id],
                |r| r.get(0),
            )
            .ok();
        if found.is_some() {
            return Value::String(suffix.to_string());
        }
    }
    Value::Null
}

// ── Dispatch: camelCase scenario method -> Rust binding call ────────────────────
// Mirrors run-ts.ts's DISPATCH. Options-bearing methods (shortestPath weightProp,
// astar latProp/lonProp, bfs/dfs maxDepth, nodeSimilarity threshold/topK, knn k)
// translate positional scenario args into the Rust API's positional arguments.
fn dispatch(g: &Graph, method: &str, args: &[Value]) -> Result<Value, StepError> {
    match method {
        // nodes
        "upsertNode" => map_res(g.upsert_node(
            str_arg(args, 0),
            props_of(args.get(1).unwrap_or(&Value::Null)),
            opt_str_arg(args, 2).unwrap_or("Node"),
        )),
        "getNode" => map_res(g.get_node(str_arg(args, 0))),
        "hasNode" => map_res(g.has_node(str_arg(args, 0))),
        "deleteNode" => map_res(g.delete_node(str_arg(args, 0))),
        "getAllNodes" => map_res(g.get_all_nodes(opt_str_arg(args, 0))),

        // edges
        "upsertEdge" => {
            let props = props_of(args.get(2).unwrap_or(&Value::Null));
            let rel = opt_str_arg(args, 3).unwrap_or("RELATED");
            match opt_str_arg(args, 4) {
                Some(edge_id) => map_res(g.upsert_edge_with_id(
                    str_arg(args, 0),
                    str_arg(args, 1),
                    props,
                    rel,
                    edge_id,
                )),
                None => map_res(g.upsert_edge(str_arg(args, 0), str_arg(args, 1), props, rel)),
            }
        }
        "getEdge" => map_res(g.get_edge(str_arg(args, 0), str_arg(args, 1), opt_str_arg(args, 2))),
        "hasEdge" => map_res(g.has_edge(str_arg(args, 0), str_arg(args, 1), opt_str_arg(args, 2))),
        "deleteEdge" => {
            map_res(g.delete_edge(str_arg(args, 0), str_arg(args, 1), opt_str_arg(args, 2)))
        }
        "getAllEdges" => map_cypher(g.get_all_edges()),

        // queries
        "nodeDegree" => map_res(g.node_degree(str_arg(args, 0))),
        "getNeighbors" => map_res(g.get_neighbors(str_arg(args, 0))),
        "getNodeEdges" => map_cypher(g.get_node_edges(str_arg(args, 0))),
        "getEdgesFrom" => map_cypher(g.get_edges_from(str_arg(args, 0))),
        "getEdgesTo" => map_cypher(g.get_edges_to(str_arg(args, 0))),
        "getEdgesByType" => map_cypher(g.get_edges_by_type(str_arg(args, 0), str_arg(args, 1))),
        "stats" => map_res(g.stats()),
        "query" => {
            let q = str_arg(args, 0);
            match args.get(1).filter(|v| !v.is_null()).and_then(Value::as_object) {
                Some(map) => {
                    let pairs: Vec<(&str, &Value)> =
                        map.iter().map(|(k, v)| (k.as_str(), v)).collect();
                    map_cypher(g.query_params(q, &pairs))
                }
                None => map_cypher(g.query(q)),
            }
        }

        // centrality
        "pagerank" => map_res(g.pagerank(
            opt_f64_arg(args, 0).unwrap_or(0.85),
            opt_i32_arg(args, 1).unwrap_or(20),
        )),
        "degreeCentrality" => map_res(g.degree_centrality()),
        "betweennessCentrality" => map_res(g.betweenness_centrality()),
        "closenessCentrality" => map_res(g.closeness_centrality()),
        "eigenvectorCentrality" => {
            map_res(g.eigenvector_centrality(opt_i32_arg(args, 0).unwrap_or(100)))
        }

        // community
        "communityDetection" => map_res(g.community_detection(opt_i32_arg(args, 0).unwrap_or(10))),
        "louvain" => map_res(g.louvain(opt_f64_arg(args, 0).unwrap_or(1.0))),
        "leidenCommunities" => Err(unsupported("leidenCommunities")),

        // components
        "weaklyConnectedComponents" => map_res(g.wcc()),
        "stronglyConnectedComponents" => map_res(g.scc()),

        // paths
        "shortestPath" => map_res(g.shortest_path(
            str_arg(args, 0),
            str_arg(args, 1),
            opt_str_arg(args, 2),
        )),
        "astar" => map_res(g.astar(
            str_arg(args, 0),
            str_arg(args, 1),
            opt_str_arg(args, 2),
            opt_str_arg(args, 3),
        )),
        "allPairsShortestPath" => map_res(g.apsp()),

        // traversal
        "bfs" => map_res(g.bfs(str_arg(args, 0), opt_i32_arg(args, 1))),
        "dfs" => map_res(g.dfs(str_arg(args, 0), opt_i32_arg(args, 1))),

        // similarity
        "nodeSimilarity" => map_res(g.node_similarity(
            opt_str_arg(args, 0),
            opt_str_arg(args, 1),
            opt_f64_arg(args, 2).unwrap_or(0.0),
            opt_i32_arg(args, 3).unwrap_or(0),
        )),
        "knn" => map_res(g.knn(str_arg(args, 0), opt_i32_arg(args, 1).unwrap_or(10))),
        "triangleCount" => map_res(g.triangle_count()),

        // bulk — raw SQL, bypasses Cypher (cypher-mode captures stay empty).
        "insertNodesBulk" => map_res(g.insert_nodes_bulk(build_nodes(args.first()))),
        "insertEdgesBulk" => {
            let edges = build_edges(args.first());
            let id_map = build_id_map(args.get(1));
            map_res(g.insert_edges_bulk(edges, &id_map))
        }
        "insertGraphBulk" => {
            let nodes = build_nodes(args.first());
            let edges = build_edges(args.get(1));
            match g.insert_graph_bulk(nodes, edges) {
                Ok(r) => {
                    let id_map: Map<String, Value> =
                        r.id_map.iter().map(|(k, v)| (k.clone(), json!(v))).collect();
                    Ok(json!({
                        "nodesInserted": r.nodes_inserted,
                        "edgesInserted": r.edges_inserted,
                        "idMap": Value::Object(id_map),
                    }))
                }
                Err(e) => Err(to_step_err(e)),
            }
        }
        "resolveNodeIds" => {
            let ids: Vec<String> = args
                .first()
                .and_then(Value::as_array)
                .map(|a| {
                    a.iter()
                        .filter_map(Value::as_str)
                        .map(str::to_string)
                        .collect()
                })
                .unwrap_or_default();
            map_res(g.resolve_node_ids(ids))
        }
        "bulkPropTable" => Ok(bulk_prop_table(g, str_arg(args, 0), str_arg(args, 1))),

        // export — Python-only; no Rust binding (allowlisted divergence).
        "toRustworkx" => Err(unsupported("toRustworkx")),

        other => Err(StepError {
            err_type: "Error".to_string(),
            message: format!("Unknown method in scenario: {other}"),
        }),
    }
}

fn run_fixture(g: &Graph, fixture: &[Value]) {
    for op in fixture {
        let method = op.get("method").and_then(Value::as_str).unwrap_or("");
        let args = op
            .get("args")
            .and_then(Value::as_array)
            .cloned()
            .unwrap_or_default();
        // Fixture failures would surface as scenario-wide breakage; mirror the
        // TS/Python runners which let fixture ops run unconditionally.
        let _ = dispatch(g, method, &args);
    }
}

fn parse_args() -> (Mode, PathBuf) {
    // Default: the shared scenarios.json next to the TS/Python runners,
    // resolved relative to this crate (bindings/rust -> bindings/typescript/...).
    let default_scenarios = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .map(|p| p.join("typescript/test/parity/scenarios.json"))
        .unwrap_or_else(|| PathBuf::from("scenarios.json"));

    let mut mode = Mode::Results;
    let mut scenarios = default_scenarios;

    let argv: Vec<String> = std::env::args().skip(1).collect();
    let mut i = 0;
    while i < argv.len() {
        match argv[i].as_str() {
            "--mode" => {
                if let Some(next) = argv.get(i + 1) {
                    mode = if next == "cypher" {
                        Mode::Cypher
                    } else {
                        Mode::Results
                    };
                    i += 1;
                }
            }
            "--scenarios" => {
                if let Some(next) = argv.get(i + 1) {
                    scenarios = PathBuf::from(next);
                    i += 1;
                }
            }
            _ => {}
        }
        i += 1;
    }
    (mode, scenarios)
}

fn main() {
    let (mode, scenarios_path) = parse_args();

    let raw = fs::read_to_string(&scenarios_path).unwrap_or_else(|e| {
        panic!("failed to read scenarios {}: {e}", scenarios_path.display())
    });
    let spec: Value = serde_json::from_str(&raw).expect("failed to parse scenarios.json");

    let fixture = spec
        .get("fixture")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    let scenarios = spec
        .get("scenarios")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();

    let mut out_scenarios: Vec<Value> = Vec::new();

    for scenario in &scenarios {
        let sid = scenario.get("id").and_then(Value::as_str).unwrap_or("");
        let group = scenario.get("group").and_then(Value::as_str);
        let steps_spec = scenario
            .get("steps")
            .and_then(Value::as_array)
            .cloned()
            .unwrap_or_default();

        let g = graph(":memory:").expect("failed to open in-memory graph");
        run_fixture(&g, &fixture);

        // Start capturing only after the fixture so its Cypher is discarded.
        #[cfg(feature = "parity-spy")]
        if mode == Mode::Cypher {
            g.connection().parity_start_recording();
        }

        let mut step_results: Vec<Value> = Vec::new();
        for step in &steps_spec {
            let step_id = step.get("id").and_then(Value::as_str).unwrap_or("");
            let step_method = step.get("method").and_then(Value::as_str).unwrap_or("");
            let step_args = step
                .get("args")
                .and_then(Value::as_array)
                .cloned()
                .unwrap_or_default();

            // Clear any residue so each step captures only its own calls.
            #[cfg(feature = "parity-spy")]
            if mode == Mode::Cypher {
                let _ = g.connection().parity_take_recording();
            }

            let mut rec = Map::new();
            rec.insert("id".into(), json!(step_id));
            rec.insert("method".into(), json!(step_method));
            rec.insert("args".into(), Value::Array(step_args.clone()));

            match dispatch(&g, step_method, &step_args) {
                Ok(value) => {
                    rec.insert("status".into(), json!("ok"));
                    if mode == Mode::Results {
                        rec.insert("value".into(), value);
                    }
                }
                Err(e) => {
                    rec.insert("status".into(), json!("error"));
                    rec.insert(
                        "error".into(),
                        json!({ "type": e.err_type, "message": e.message }),
                    );
                }
            }

            if mode == Mode::Cypher {
                #[cfg(feature = "parity-spy")]
                let calls = g.connection().parity_take_recording();
                #[cfg(not(feature = "parity-spy"))]
                let calls: Vec<Value> = Vec::new();
                rec.insert("cypher".into(), Value::Array(calls));
            }

            step_results.push(Value::Object(rec));
        }

        let mut sc = Map::new();
        sc.insert("id".into(), json!(sid));
        sc.insert("group".into(), group.map(|g| json!(g)).unwrap_or(Value::Null));
        sc.insert("steps".into(), Value::Array(step_results));
        out_scenarios.push(Value::Object(sc));
    }

    let out = json!({
        "binding": "rust",
        "mode": match mode { Mode::Results => "results", Mode::Cypher => "cypher" },
        "scenarios": out_scenarios,
    });

    println!("{}", serde_json::to_string(&out).expect("serialize output"));
}
