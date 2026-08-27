# before — 자동 감지 거짓 주장 (수정 전)

## python/manager.py:214,222
        Uses the FROM clause syntax to query across multiple graphs.
            graphs: List of graph names to attach (auto-detected from query if None)

## rust/manager.rs:233
    /// Graphs are automatically attached to the coordinator connection.

## python-api.md:556
| `query` | `manager.query(cypher: str, graphs: list[str] = None, params: dict = None) -> list` | Query across multiple graphs; `graphs=None` queries all |

## rust-api.md:236
fn query(&self, cypher: &str, graphs: Option<&[&str]>, params: Option<&serde_json::Value>) -> Result<Vec<serde_json::Value>>
