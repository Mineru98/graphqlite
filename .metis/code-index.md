# Code Index

> Generated: 2026-05-19T23:50:21Z | 73 files | JavaScript, Python, Rust

## Project Structure

```
├── bindings/
│   ├── python/
│   │   ├── src/
│   │   │   └── graphqlite/
│   │   │       ├── __init__.py
│   │   │       ├── _platform.py
│   │   │       ├── algorithms/
│   │   │       │   ├── __init__.py
│   │   │       │   ├── _parsing.py
│   │   │       │   ├── centrality.py
│   │   │       │   ├── community.py
│   │   │       │   ├── components.py
│   │   │       │   ├── export.py
│   │   │       │   ├── paths.py
│   │   │       │   ├── similarity.py
│   │   │       │   └── traversal.py
│   │   │       ├── connection.py
│   │   │       ├── graph/
│   │   │       │   ├── __init__.py
│   │   │       │   ├── _base.py
│   │   │       │   ├── batch.py
│   │   │       │   ├── bulk.py
│   │   │       │   ├── edges.py
│   │   │       │   ├── nodes.py
│   │   │       │   └── queries.py
│   │   │       ├── manager.py
│   │   │       └── utils.py
│   │   └── tests/
│   │       ├── test_connection.py
│   │       ├── test_graph.py
│   │       ├── test_manager.py
│   │       └── test_new_functions.py
│   └── rust/
│       ├── build.rs
│       ├── examples/
│       │   └── tck_runner.rs
│       ├── src/
│       │   ├── algorithms/
│       │   │   ├── centrality.rs
│       │   │   ├── community.rs
│       │   │   ├── components.rs
│       │   │   ├── mod.rs
│       │   │   ├── parsing.rs
│       │   │   ├── paths.rs
│       │   │   ├── similarity.rs
│       │   │   └── traversal.rs
│       │   ├── connection.rs
│       │   ├── error.rs
│       │   ├── graph/
│       │   │   ├── batch.rs
│       │   │   ├── bulk.rs
│       │   │   ├── edges.rs
│       │   │   ├── mod.rs
│       │   │   ├── nodes.rs
│       │   │   └── queries.rs
│       │   ├── lib.rs
│       │   ├── manager.rs
│       │   ├── platform.rs
│       │   ├── query_builder.rs
│       │   ├── result.rs
│       │   └── utils.rs
│       └── tests/
│           └── integration.rs
├── docs/
│   └── theme/
│       └── version-select.js
├── examples/
│   └── llm-graphrag/
│       ├── analyze.py
│       ├── hotpotqa.py
│       ├── ingest.py
│       ├── ollama_client.py
│       └── rag.py
└── tests/
    └── tck/
        ├── __init__.py
        ├── __main__.py
        ├── _extension_worker.py
        ├── _python_binding_worker.py
        ├── backends/
        │   ├── __init__.py
        │   ├── base.py
        │   ├── extension.py
        │   ├── python_binding.py
        │   └── rust_binding.py
        ├── gherkin.py
        ├── report.py
        ├── runner.py
        ├── tests/
        │   ├── __init__.py
        │   ├── test_gherkin.py
        │   ├── test_smoke_extension.py
        │   └── test_values.py
        └── values.py
```

## Modules

