-- ========================================================================
-- Test 34: Bulk Property SET (SET n = {map}, SET n += {map})
-- ========================================================================
-- PURPOSE: End-to-end testing of bulk property SET operations including
--          replace semantics (=), merge semantics (+=), edge support,
--          mixed types, JSON values, and integration with RETURN/WHERE.
-- COVERS:  SET n = {map}, SET n += {map}, SET r = {map}, SET r += {map}
-- ========================================================================

.load ./build/graphqlite

SELECT '=== Test 34: Bulk Property SET ===' as test_section;

-- ========================================================================
-- SECTION 1: Basic SET n = {map} (Replace)
-- ========================================================================
SELECT '=== Section 1: Basic SET n = {map} (Replace) ===' as section;

SELECT 'Test 1.1 - SET n = {map} replaces all properties:' as test_name;
SELECT cypher('CREATE (n:BulkTest {name: "Alice", age: 30, city: "NYC"})') as setup;
SELECT cypher('MATCH (n:BulkTest {name: "Alice"}) RETURN n.name, n.age, n.city') as before_replace;

SELECT cypher('MATCH (n:BulkTest {name: "Alice"}) SET n = {name: "Alice", role: "admin"}') as result;
-- After replace: only name and role should exist; age and city should be gone
SELECT cypher('MATCH (n:BulkTest {name: "Alice"}) RETURN n.name, n.role') as after_replace;

SELECT 'Test 1.2 - Old properties removed after replace:' as test_name;
SELECT cypher('MATCH (n:BulkTest {name: "Alice"}) RETURN n.age') as should_be_null;
SELECT cypher('MATCH (n:BulkTest {name: "Alice"}) RETURN n.city') as should_be_null_2;

SELECT 'Test 1.3 - SET n = {map} with mixed types:' as test_name;
SELECT cypher('CREATE (n:BulkMixed {name: "placeholder"})') as setup;
SELECT cypher('MATCH (n:BulkMixed {name: "placeholder"}) SET n = {name: "Bob", count: 42, score: 3.14, active: true}') as result;
SELECT cypher('MATCH (n:BulkMixed {name: "Bob"}) RETURN n.name, n.count, n.score, n.active') as mixed_result;

SELECT 'Test 1.4 - SET n = {} clears all properties:' as test_name;
SELECT cypher('CREATE (n:BulkClear {x: 1, y: 2, z: 3})') as setup;
SELECT cypher('MATCH (n:BulkClear) SET n = {}') as clear_result;
SELECT cypher('MATCH (n:BulkClear) RETURN properties(n)') as should_be_empty;

-- ========================================================================
-- SECTION 2: Basic SET n += {map} (Merge)
-- ========================================================================
SELECT '=== Section 2: Basic SET n += {map} (Merge) ===' as section;

SELECT 'Test 2.1 - SET n += {map} adds new properties:' as test_name;
SELECT cypher('CREATE (n:MergeTest {a: 1, b: 2})') as setup;
SELECT cypher('MATCH (n:MergeTest {a: 1}) SET n += {c: 3}') as result;
SELECT cypher('MATCH (n:MergeTest {a: 1}) RETURN n.a, n.b, n.c') as merge_result;

SELECT 'Test 2.2 - SET n += {map} updates existing properties:' as test_name;
SELECT cypher('MATCH (n:MergeTest {a: 1}) SET n += {a: 10}') as result;
SELECT cypher('MATCH (n:MergeTest {a: 10}) RETURN n.a, n.b, n.c') as updated_result;

SELECT 'Test 2.3 - SET n += {map} updates and adds simultaneously:' as test_name;
SELECT cypher('MATCH (n:MergeTest {a: 10}) SET n += {b: 20, d: 4}') as result;
SELECT cypher('MATCH (n:MergeTest {a: 10}) RETURN n.a, n.b, n.c, n.d') as update_add_result;

-- ========================================================================
-- SECTION 3: Replace vs Merge Semantics
-- ========================================================================
SELECT '=== Section 3: Replace vs Merge Semantics ===' as section;

SELECT 'Test 3.1 - Replace keeps only new properties:' as test_name;
SELECT cypher('CREATE (n:SemTest {x: 1, y: 2, z: 3})') as setup;
SELECT cypher('MATCH (n:SemTest {x: 1}) SET n = {x: 10}') as replace_result;
SELECT cypher('MATCH (n:SemTest {x: 10}) RETURN n.x, n.y, n.z') as verify_replace;

SELECT 'Test 3.2 - Merge preserves existing properties:' as test_name;
SELECT cypher('CREATE (n:SemTest2 {x: 1, y: 2, z: 3})') as setup;
SELECT cypher('MATCH (n:SemTest2 {x: 1}) SET n += {x: 10}') as merge_result;
SELECT cypher('MATCH (n:SemTest2 {x: 10}) RETURN n.x, n.y, n.z') as verify_merge;

-- ========================================================================
-- SECTION 4: Edge Bulk SET
-- ========================================================================
SELECT '=== Section 4: Edge Bulk SET ===' as section;

SELECT 'Test 4.1 - SET r = {map} on edge:' as test_name;
SELECT cypher('CREATE (a:EdgeBulk {name: "A"}), (b:EdgeBulk {name: "B"})') as setup;
SELECT cypher('MATCH (a:EdgeBulk {name: "A"}), (b:EdgeBulk {name: "B"}) CREATE (a)-[:KNOWS {since: 2020, strength: 5}]->(b)') as setup2;
SELECT cypher('MATCH (a:EdgeBulk {name: "A"})-[r:KNOWS]->(b) SET r = {weight: 10, label: "friend"}') as replace_edge;
SELECT cypher('MATCH (a:EdgeBulk {name: "A"})-[r:KNOWS]->(b) RETURN r.weight, r.label') as edge_result;

SELECT 'Test 4.2 - Old edge properties removed after replace:' as test_name;
SELECT cypher('MATCH (a:EdgeBulk {name: "A"})-[r:KNOWS]->(b) RETURN r.since') as should_be_null;

SELECT 'Test 4.3 - SET r += {map} on edge:' as test_name;
SELECT cypher('MATCH (a:EdgeBulk {name: "A"})-[r:KNOWS]->(b) SET r += {extra: true}') as merge_edge;
SELECT cypher('MATCH (a:EdgeBulk {name: "A"})-[r:KNOWS]->(b) RETURN r.weight, r.label, r.extra') as edge_merge_result;

-- ========================================================================
-- SECTION 5: JSON/Nested Values in Bulk SET
-- ========================================================================
SELECT '=== Section 5: JSON/Nested Values in Bulk SET ===' as section;

SELECT 'Test 5.1 - Bulk SET with JSON map property:' as test_name;
SELECT cypher('CREATE (n:JsonBulk {name: "placeholder"})') as setup;
SELECT cypher('MATCH (n:JsonBulk {name: "placeholder"}) SET n = {name: "Charlie", meta: {role: "admin", level: 5}, tags: [1, 2, 3]}') as result;
SELECT cypher('MATCH (n:JsonBulk {name: "Charlie"}) RETURN n.name, n.meta, n.tags') as json_result;

SELECT 'Test 5.2 - Access nested JSON after bulk SET:' as test_name;
SELECT cypher('MATCH (n:JsonBulk {name: "Charlie"}) RETURN n.meta.role') as nested_result;

SELECT 'Test 5.3 - Merge with JSON property:' as test_name;
SELECT cypher('MATCH (n:JsonBulk {name: "Charlie"}) SET n += {meta: {role: "user"}}') as merge_json;
SELECT cypher('MATCH (n:JsonBulk {name: "Charlie"}) RETURN n.meta.role') as merged_json_result;

-- ========================================================================
-- SECTION 6: WHERE + RETURN Integration
-- ========================================================================
SELECT '=== Section 6: WHERE + RETURN Integration ===' as section;

SELECT 'Test 6.1 - Bulk SET with WHERE filtering:' as test_name;
SELECT cypher('CREATE (n:FilterBulk {name: "X", status: "active"})') as setup;
SELECT cypher('CREATE (n:FilterBulk {name: "Y", status: "inactive"})') as setup2;
SELECT cypher('MATCH (n:FilterBulk) WHERE n.status = "active" SET n = {name: "X", status: "active", updated: true}') as filtered_set;
SELECT cypher('MATCH (n:FilterBulk {name: "X"}) RETURN n.updated') as should_be_true;
SELECT cypher('MATCH (n:FilterBulk {name: "Y"}) RETURN n.status') as should_be_inactive;

SELECT 'Test 6.2 - Merge SET with properties() verification:' as test_name;
SELECT cypher('CREATE (n:PropCheck {a: 1, b: 2})') as setup;
SELECT cypher('MATCH (n:PropCheck {a: 1}) SET n += {c: 3}') as merge;
SELECT cypher('MATCH (n:PropCheck {a: 1}) RETURN properties(n)') as all_props;

-- ========================================================================
-- SECTION 7: Multiple Bulk SETs
-- ========================================================================
SELECT '=== Section 7: Multiple Bulk SETs ===' as section;

SELECT 'Test 7.1 - Multiple SET items in one query:' as test_name;
SELECT cypher('CREATE (n:Multi1 {name: "A"}), (m:Multi2 {name: "B"})') as setup;
SELECT cypher('MATCH (n:Multi1 {name: "A"}), (m:Multi2 {name: "B"}) SET n += {x: 1}, m += {y: 2}') as multi_set;
SELECT cypher('MATCH (n:Multi1 {name: "A"}) RETURN n.x') as multi_n;
SELECT cypher('MATCH (m:Multi2 {name: "B"}) RETURN m.y') as multi_m;

SELECT 'Test 7.2 - Mix property SET and bulk SET:' as test_name;
SELECT cypher('CREATE (n:MixSet {name: "C"})') as setup;
SELECT cypher('MATCH (n:MixSet {name: "C"}) SET n.age = 25, n += {role: "dev"}') as mix_set;
SELECT cypher('MATCH (n:MixSet {name: "C"}) RETURN n.name, n.age, n.role') as mix_result;

-- ========================================================================
-- SECTION 8: keys() and labels after bulk SET
-- ========================================================================
SELECT '=== Section 8: keys() and labels ===' as section;

SELECT 'Test 8.1 - keys() reflects bulk SET:' as test_name;
SELECT cypher('CREATE (n:KeyTest {old: 1})') as setup;
SELECT cypher('MATCH (n:KeyTest) SET n = {new_a: 10, new_b: 20}') as replace;
SELECT cypher('MATCH (n:KeyTest) RETURN keys(n)') as keys_result;

SELECT 'Test 8.2 - Labels preserved after bulk SET:' as test_name;
SELECT cypher('MATCH (n:KeyTest) RETURN labels(n)') as labels_result;

SELECT '=== Bulk SET Test Complete ===' as test_section;
