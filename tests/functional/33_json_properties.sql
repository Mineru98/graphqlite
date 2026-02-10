-- ========================================================================
-- Test 33: JSON Property Storage and Nested Access
-- ========================================================================
-- PURPOSE: End-to-end testing of native JSON property storage including
--          map/list literals in CREATE and SET, dot/bracket access,
--          deep nesting, WHERE comparisons, and JSON helper functions.
-- COVERS:  PROP_TYPE_JSON storage, COALESCE chain JSON arm,
--          json_get(), json_keys(), json_type() functions,
--          edge JSON properties, mixed scalar+JSON properties
-- ========================================================================

.load ./build/graphqlite

SELECT '=== Test 33: JSON Property Storage and Nested Access ===' as test_section;

-- ========================================================================
-- SECTION 1: CREATE with Map Literals
-- ========================================================================
SELECT '=== Section 1: CREATE with Map Literals ===' as section;

SELECT 'Test 1.1 - CREATE node with simple map property:' as test_name;
SELECT cypher('CREATE (n:JsonTest {name: "Alice", metadata: {role: "admin", level: 5}})') as result;

SELECT 'Test 1.2 - CREATE node with nested map property:' as test_name;
SELECT cypher('CREATE (n:JsonTest {name: "Bob", metadata: {role: "user", prefs: {theme: "dark", lang: "en"}}})') as result;

SELECT 'Test 1.3 - Read back simple map property:' as test_name;
SELECT cypher('MATCH (n:JsonTest {name: "Alice"}) RETURN n.metadata') as result;

SELECT 'Test 1.4 - Read back nested map property:' as test_name;
SELECT cypher('MATCH (n:JsonTest {name: "Bob"}) RETURN n.metadata') as result;

-- ========================================================================
-- SECTION 2: CREATE with List Literals
-- ========================================================================
SELECT '=== Section 2: CREATE with List Literals ===' as section;

SELECT 'Test 2.1 - CREATE node with integer list:' as test_name;
SELECT cypher('CREATE (n:ListTest {name: "Numbers", tags: [1, 2, 3, 4, 5]})') as result;

SELECT 'Test 2.2 - CREATE node with string list:' as test_name;
SELECT cypher('CREATE (n:ListTest {name: "Colors", items: ["red", "green", "blue"]})') as result;

SELECT 'Test 2.3 - CREATE node with mixed list:' as test_name;
SELECT cypher('CREATE (n:ListTest {name: "Mixed", data: [1, "two", 3.14, true]})') as result;

SELECT 'Test 2.4 - Read back integer list:' as test_name;
SELECT cypher('MATCH (n:ListTest {name: "Numbers"}) RETURN n.tags') as result;

SELECT 'Test 2.5 - Read back string list:' as test_name;
SELECT cypher('MATCH (n:ListTest {name: "Colors"}) RETURN n.items') as result;

-- ========================================================================
-- SECTION 3: SET Map/List Properties
-- ========================================================================
SELECT '=== Section 3: SET Map/List Properties ===' as section;

SELECT 'Test 3.1 - SET map property on existing node:' as test_name;
SELECT cypher('CREATE (n:SetTest {name: "Charlie"})') as setup;
SELECT cypher('MATCH (n:SetTest {name: "Charlie"}) SET n.config = {timeout: 30, retries: 3}') as result;

SELECT 'Test 3.2 - Read back SET map property:' as test_name;
SELECT cypher('MATCH (n:SetTest {name: "Charlie"}) RETURN n.config') as result;

SELECT 'Test 3.3 - SET list property on existing node:' as test_name;
SELECT cypher('MATCH (n:SetTest {name: "Charlie"}) SET n.scores = [95, 87, 92]') as result;

SELECT 'Test 3.4 - Read back SET list property:' as test_name;
SELECT cypher('MATCH (n:SetTest {name: "Charlie"}) RETURN n.scores') as result;

SELECT 'Test 3.5 - Overwrite scalar with map:' as test_name;
SELECT cypher('CREATE (n:OverwriteTest {name: "Dana", info: "plain text"})') as setup;
SELECT cypher('MATCH (n:OverwriteTest {name: "Dana"}) SET n.info = {structured: true, format: "json"}') as result;
SELECT cypher('MATCH (n:OverwriteTest {name: "Dana"}) RETURN n.info') as result;

-- ========================================================================
-- SECTION 4: Dot Access on JSON Properties
-- ========================================================================
SELECT '=== Section 4: Dot Access on JSON Properties ===' as section;

SELECT 'Test 4.1 - Access map key via dot notation:' as test_name;
SELECT cypher('MATCH (n:JsonTest {name: "Alice"}) RETURN n.metadata.role') as result;

SELECT 'Test 4.2 - Access numeric value via dot:' as test_name;
SELECT cypher('MATCH (n:JsonTest {name: "Alice"}) RETURN n.metadata.level') as result;

SELECT 'Test 4.3 - Access nested map via dot:' as test_name;
SELECT cypher('MATCH (n:JsonTest {name: "Bob"}) RETURN n.metadata.prefs') as result;

SELECT 'Test 4.4 - Access nested scalar via dot:' as test_name;
SELECT cypher('MATCH (n:JsonTest {name: "Bob"}) RETURN n.metadata.prefs.theme') as result;

-- ========================================================================
-- SECTION 5: Bracket Access on JSON Properties
-- ========================================================================
SELECT '=== Section 5: Bracket Access on JSON Properties ===' as section;

SELECT 'Test 5.1 - Access map key via bracket:' as test_name;
SELECT cypher('MATCH (n:JsonTest {name: "Alice"}) RETURN n.metadata["role"]') as result;

SELECT 'Test 5.2 - Access list element by index:' as test_name;
SELECT cypher('MATCH (n:ListTest {name: "Numbers"}) RETURN n.tags[0]') as result;

SELECT 'Test 5.3 - Access another list index:' as test_name;
SELECT cypher('MATCH (n:ListTest {name: "Numbers"}) RETURN n.tags[2]') as result;

SELECT 'Test 5.4 - Access string list element:' as test_name;
SELECT cypher('MATCH (n:ListTest {name: "Colors"}) RETURN n.items[1]') as result;

-- ========================================================================
-- SECTION 6: Deep Nesting
-- ========================================================================
SELECT '=== Section 6: Deep Nesting ===' as section;

SELECT 'Test 6.1 - Three levels deep:' as test_name;
SELECT cypher('MATCH (n:JsonTest {name: "Bob"}) RETURN n.metadata.prefs.lang') as result;

SELECT 'Test 6.2 - Create deeply nested structure:' as test_name;
SELECT cypher('CREATE (n:DeepJson {name: "Deep", data: {a: {b: {c: {d: "found"}}}}})') as result;

SELECT 'Test 6.3 - Access four levels deep:' as test_name;
SELECT cypher('MATCH (n:DeepJson {name: "Deep"}) RETURN n.data.a.b.c.d') as result;

SELECT 'Test 6.4 - Access intermediate nested object:' as test_name;
SELECT cypher('MATCH (n:DeepJson {name: "Deep"}) RETURN n.data.a.b') as result;

-- ========================================================================
-- SECTION 7: WHERE Comparisons with JSON Properties
-- ========================================================================
SELECT '=== Section 7: WHERE Comparisons ===' as section;

SELECT 'Test 7.1 - WHERE on nested string value:' as test_name;
SELECT cypher('MATCH (n:JsonTest) WHERE n.metadata.role = "admin" RETURN n.name') as result;

SELECT 'Test 7.2 - WHERE on nested numeric value:' as test_name;
SELECT cypher('MATCH (n:JsonTest) WHERE n.metadata.level = 5 RETURN n.name') as result;

SELECT 'Test 7.3 - WHERE with numeric comparison:' as test_name;
SELECT cypher('MATCH (n:SetTest) WHERE n.config.timeout > 20 RETURN n.name') as result;

SELECT 'Test 7.4 - WHERE on deeply nested value:' as test_name;
SELECT cypher('MATCH (n:JsonTest) WHERE n.metadata.prefs.theme = "dark" RETURN n.name') as result;

-- ========================================================================
-- SECTION 8: Helper Functions
-- ========================================================================
SELECT '=== Section 8: JSON Helper Functions ===' as section;

SELECT 'Test 8.1 - json_get with simple key:' as test_name;
SELECT cypher('MATCH (n:JsonTest {name: "Alice"}) RETURN json_get(n.metadata, "role")') as result;

SELECT 'Test 8.2 - json_get with dollar-path:' as test_name;
SELECT cypher('MATCH (n:JsonTest {name: "Bob"}) RETURN json_get(n.metadata, "$.prefs.theme")') as result;

SELECT 'Test 8.3 - json_keys on map property:' as test_name;
SELECT cypher('MATCH (n:JsonTest {name: "Alice"}) RETURN json_keys(n.metadata)') as result;

SELECT 'Test 8.4 - json_type on map property:' as test_name;
SELECT cypher('MATCH (n:JsonTest {name: "Alice"}) RETURN json_type(n.metadata)') as result;

SELECT 'Test 8.5 - json_type on list property:' as test_name;
SELECT cypher('MATCH (n:ListTest {name: "Numbers"}) RETURN json_type(n.tags)') as result;

-- ========================================================================
-- SECTION 9: Edge JSON Properties
-- ========================================================================
SELECT '=== Section 9: Edge JSON Properties ===' as section;

SELECT 'Test 9.1 - CREATE edge with map property:' as test_name;
SELECT cypher('CREATE (a:EdgeJsonTest {name: "Server1"}), (b:EdgeJsonTest {name: "Server2"})') as setup;
SELECT cypher('MATCH (a:EdgeJsonTest {name: "Server1"}), (b:EdgeJsonTest {name: "Server2"}) CREATE (a)-[:CONNECTS {config: {port: 8080, ssl: true}}]->(b)') as result;

SELECT 'Test 9.2 - Read edge map property:' as test_name;
SELECT cypher('MATCH (a:EdgeJsonTest {name: "Server1"})-[r:CONNECTS]->(b) RETURN r.config') as result;

SELECT 'Test 9.3 - Access nested edge property:' as test_name;
SELECT cypher('MATCH (a:EdgeJsonTest {name: "Server1"})-[r:CONNECTS]->(b) RETURN r.config.port') as result;

SELECT 'Test 9.4 - SET map on edge:' as test_name;
SELECT cypher('MATCH (a:EdgeJsonTest {name: "Server1"})-[r:CONNECTS]->(b) SET r.metrics = {latency: 5, uptime: 99.9}') as result;
SELECT cypher('MATCH (a:EdgeJsonTest {name: "Server1"})-[r:CONNECTS]->(b) RETURN r.metrics.latency') as result;

-- ========================================================================
-- SECTION 10: Mixed Scalar + JSON Properties
-- ========================================================================
SELECT '=== Section 10: Mixed Scalar + JSON ===' as section;

SELECT 'Test 10.1 - Node with both scalar and JSON properties:' as test_name;
SELECT cypher('CREATE (n:MixedTest {name: "Eve", age: 28, metadata: {department: "Engineering"}, tags: ["python", "rust"]})') as result;

SELECT 'Test 10.2 - Access scalar property:' as test_name;
SELECT cypher('MATCH (n:MixedTest {name: "Eve"}) RETURN n.age') as result;

SELECT 'Test 10.3 - Access JSON map property:' as test_name;
SELECT cypher('MATCH (n:MixedTest {name: "Eve"}) RETURN n.metadata.department') as result;

SELECT 'Test 10.4 - Access JSON list property:' as test_name;
SELECT cypher('MATCH (n:MixedTest {name: "Eve"}) RETURN n.tags') as result;

SELECT 'Test 10.5 - Return multiple property types together:' as test_name;
SELECT cypher('MATCH (n:MixedTest {name: "Eve"}) RETURN n.name, n.age, n.metadata, n.tags') as result;

SELECT 'Test 10.6 - properties() includes JSON properties:' as test_name;
SELECT cypher('MATCH (n:MixedTest {name: "Eve"}) RETURN properties(n)') as result;

SELECT 'Test 10.7 - keys() includes JSON property keys:' as test_name;
SELECT cypher('MATCH (n:MixedTest {name: "Eve"}) RETURN keys(n)') as result;

-- ========================================================================
-- SECTION 11: List of Maps
-- ========================================================================
SELECT '=== Section 11: List of Maps ===' as section;

SELECT 'Test 11.1 - CREATE with list of maps:' as test_name;
SELECT cypher('CREATE (n:ComplexJson {name: "Config", entries: [{key: "a", val: 1}, {key: "b", val: 2}]})') as result;

SELECT 'Test 11.2 - Read list of maps:' as test_name;
SELECT cypher('MATCH (n:ComplexJson {name: "Config"}) RETURN n.entries') as result;

SELECT 'Test 11.3 - Access first element of list:' as test_name;
SELECT cypher('MATCH (n:ComplexJson {name: "Config"}) RETURN n.entries[0]') as result;

-- ========================================================================
-- SECTION 12: RETURN Whole Node/Edge with JSON Properties (GH Issue #22)
-- ========================================================================
-- BUG: json_group_object treats JSON values as TEXT strings, causing
--      double-escaping. e.g. "pills":"[\"red\",\"blue\"]" instead of
--      "pills":["red","blue"]. The fix wraps JSON values with json().
-- NOTE: Tests use separate CREATE + MATCH to avoid CREATE+RETURN issue.
-- ========================================================================
SELECT '=== Section 12: RETURN Whole Node/Edge with JSON Properties ===' as section;

-- Setup: create all test nodes first
SELECT cypher('CREATE (n:ReturnJsonTest {name: "tc1", tags: [1, 2, 3]})') as setup;
SELECT cypher('CREATE (n:ReturnJsonTest {name: "tc2", colors: ["red", "blue"]})') as setup;
SELECT cypher('CREATE (n:ReturnJsonTest {name: "tc3", meta: {role: "admin", level: 5}})') as setup;
SELECT cypher('CREATE (n:ReturnJsonTest {name: "tc4", age: 30, tags: ["a", "b"]})') as setup;
SELECT cypher('CREATE (a:ReturnJsonTest {name: "tc5a"})-[r:TAGGED {labels: ["x", "y"]}]->(b:ReturnJsonTest {name: "tc5b"})') as setup;
SELECT cypher('CREATE (n:ReturnJsonTest {name: "tc9", entries: [{k: "a", v: 1}, {k: "b", v: 2}]})') as setup;

SELECT 'Test 12.1 - RETURN node with integer list property:' as test_name;
SELECT cypher('MATCH (n:ReturnJsonTest {name: "tc1"}) RETURN n') as result;
-- Expected: "tags":[1,2,3]  NOT "tags":"[1,2,3]"

SELECT 'Test 12.2 - RETURN node with string list property:' as test_name;
SELECT cypher('MATCH (n:ReturnJsonTest {name: "tc2"}) RETURN n') as result;
-- Expected: "colors":["red","blue"]  NOT "colors":"[\"red\",\"blue\"]"

SELECT 'Test 12.3 - RETURN node with map property:' as test_name;
SELECT cypher('MATCH (n:ReturnJsonTest {name: "tc3"}) RETURN n') as result;
-- Expected: "meta":{"role":"admin","level":5}  NOT escaped string

SELECT 'Test 12.4 - RETURN node with mixed scalar + JSON:' as test_name;
SELECT cypher('MATCH (n:ReturnJsonTest {name: "tc4"}) RETURN n') as result;
-- Expected: "tags":["a","b"] with scalar "name","age" unaffected

SELECT 'Test 12.5 - RETURN edge with list property:' as test_name;
SELECT cypher('MATCH (a:ReturnJsonTest {name: "tc5a"})-[r:TAGGED]->(b) RETURN r') as result;
-- Expected: "labels":["x","y"]  NOT escaped string

SELECT 'Test 12.6 - properties() with JSON values:' as test_name;
SELECT cypher('MATCH (n:ReturnJsonTest {name: "tc1"}) RETURN properties(n)') as result;
-- Expected: "tags":[1,2,3]  NOT escaped

SELECT 'Test 12.7 - Map projection {.*} with JSON values:' as test_name;
SELECT cypher('MATCH (n:ReturnJsonTest {name: "tc2"}) RETURN n{.*}') as result;
-- Expected: "colors":["red","blue"]  NOT escaped

SELECT 'Test 12.8 - RETURN node with nested list of maps:' as test_name;
SELECT cypher('MATCH (n:ReturnJsonTest {name: "tc9"}) RETURN n') as result;
-- Expected: "entries":[{"k":"a","v":1},{"k":"b","v":2}]

SELECT 'Test 12.9 - properties() on edge with JSON:' as test_name;
SELECT cypher('MATCH (a:ReturnJsonTest {name: "tc5a"})-[r:TAGGED]->(b) RETURN properties(r)') as result;
-- Expected: "labels":["x","y"]  NOT escaped

SELECT '=== JSON Properties Test Complete ===' as test_section;
