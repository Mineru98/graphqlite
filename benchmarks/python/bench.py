#!/usr/bin/env python3
"""Python binding benchmark for #86 — binding-layer overhead measurement.

Drives the graphqlite Python binding through a fixed set of operations against a
fresh in-memory graph, timing each op with ``time.perf_counter``. Emits a single
JSON document on stdout so ``benchmarks/run.sh`` can collect it alongside the TS
and Rust legs and render a comparison table.

IMPORTANT: all three language benchmarks share the *same* C core
(``src/extension.c``) via the same staged dylib (GRAPHQLITE_EXTENSION_PATH). So
these numbers are NOT a measure of core algorithm speed — they measure the
per-binding overhead layered on top of that shared core: bulk-insert strategy,
value escaping/marshalling, per-call round-trips, and result parsing.

Ops (each: 1 warm-up run discarded, then --repeats measured runs, fresh
``:memory:`` graph per run):

  build     insert_graph_bulk of N nodes + E edges (bulk path)
  lookup    get_node x L individual round-trips (default 2000)
  scan      query("MATCH (n) RETURN n.id") returning all rows (result marshalling)
  pagerank  pagerank(0.85, 20)
  bfs       bfs(seed) full traversal

Usage:
  python bench.py [--nodes 5000] [--edges 10000] [--repeats 3] [--lookups 2000]
"""
from __future__ import annotations

import argparse
import json
import platform
import statistics
import sys
import time
from typing import Any, Callable

import graphqlite

# Deterministic dataset multiplier — shared across the Python/TS/Rust runners so
# every binding builds the byte-identical graph.
EDGE_K = 3


def build_dataset(n_nodes: int, n_edges: int):
    """Deterministic (index-seeded) node/edge lists, identical across bindings.

    node id  = "n{i}",           props = {"val": i} (int), label "N"
    edge i   = ("n{i%N}" -> "n{(i*K+1)%N}"), rel "E", no props
    """
    nodes = [(f"n{i}", {"val": i}, "N") for i in range(n_nodes)]
    edges = [
        (f"n{i % n_nodes}", f"n{(i * EDGE_K + 1) % n_nodes}", {}, "E")
        for i in range(n_edges)
    ]
    return nodes, edges


def _median_min(times_ms: list[float]) -> tuple[float, float]:
    return statistics.median(times_ms), min(times_ms)


def measure(
    name: str,
    repeats: int,
    setup: Callable[[], Any],
    run: Callable[[Any], int],
    teardown: Callable[[Any], None],
) -> dict[str, Any]:
    """Run ``setup`` (untimed) then time ``run`` for 1 warm-up + ``repeats`` runs.

    ``run`` returns an integer "count" (result size / op count) used both as a
    cross-language sanity check and for reporting. The warm-up run is discarded.
    """
    times_ms: list[float] = []
    count = 0
    for r in range(repeats + 1):
        ctx = setup()
        t0 = time.perf_counter()
        count = run(ctx)
        t1 = time.perf_counter()
        teardown(ctx)
        if r > 0:  # discard warm-up (r == 0)
            times_ms.append((t1 - t0) * 1000.0)
    median_ms, min_ms = _median_min(times_ms)
    return {
        "name": name,
        "ms_median": round(median_ms, 4),
        "ms_min": round(min_ms, 4),
        "runs": len(times_ms),
        "count": count,
    }


def main() -> int:
    ap = argparse.ArgumentParser(description="graphqlite Python binding benchmark")
    ap.add_argument("--nodes", type=int, default=5000)
    ap.add_argument("--edges", type=int, default=10000)
    ap.add_argument("--repeats", type=int, default=3)
    ap.add_argument("--lookups", type=int, default=2000)
    args = ap.parse_args()

    n_nodes, n_edges = args.nodes, args.edges
    repeats, n_lookups = args.repeats, args.lookups
    nodes, edges = build_dataset(n_nodes, n_edges)
    lookup_ids = [f"n{i % n_nodes}" for i in range(n_lookups)]
    seed = "n0"

    def fresh():
        return graphqlite.graph(":memory:")

    def loaded():
        g = graphqlite.graph(":memory:")
        g.insert_graph_bulk(nodes, edges)
        return g

    def close(g):
        g.close()

    ops = []

    # build — bulk insert path (fresh empty graph, time only the insert)
    ops.append(
        measure(
            "build",
            repeats,
            setup=fresh,
            run=lambda g: g.insert_graph_bulk(nodes, edges).nodes_inserted,
            teardown=close,
        )
    )

    # lookup — L individual get_node round-trips (total time)
    def run_lookup(g) -> int:
        hits = 0
        for nid in lookup_ids:
            if g.get_node(nid) is not None:
                hits += 1
        return hits

    ops.append(
        measure("lookup", repeats, setup=loaded, run=run_lookup, teardown=close)
    )

    # scan — full result marshalling
    def run_scan(g) -> int:
        rows = g.query("MATCH (n) RETURN n.id")
        return len(rows)

    ops.append(measure("scan", repeats, setup=loaded, run=run_scan, teardown=close))

    # pagerank
    ops.append(
        measure(
            "pagerank",
            repeats,
            setup=loaded,
            run=lambda g: len(g.pagerank(0.85, 20)),
            teardown=close,
        )
    )

    # bfs
    ops.append(
        measure(
            "bfs",
            repeats,
            setup=loaded,
            run=lambda g: len(g.bfs(seed)),
            teardown=close,
        )
    )

    out = {
        "binding": "python",
        "env": {
            "python": platform.python_version(),
            "implementation": sys.implementation.name,
            "platform": platform.platform(),
            "machine": platform.machine(),
        },
        "params": {
            "nodes": n_nodes,
            "edges": n_edges,
            "repeats": repeats,
            "lookups": n_lookups,
        },
        "ops": ops,
    }
    json.dump(out, sys.stdout)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
