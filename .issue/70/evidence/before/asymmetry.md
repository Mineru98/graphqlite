# before — upsertNode id 비대칭 (수정 전)

## TS nodes.ts:105
): void {

## Python nodes.py:66
        props = {"id": node_id, **node_data}

## Rust nodes.rs 생성 경로 (id 먼저 + props 뒤)
67:            let mut prop_parts = vec![format!("id: '{}'", escape_string(node_id))];
69:                prop_parts.push(format!("{}: {}", k, v.to_cypher()));
71:            let prop_str = prop_parts.join(", ");
