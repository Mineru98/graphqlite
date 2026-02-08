-- ========================================================================
-- Test 35: Mutation + RETURN (SET/REMOVE/MERGE with RETURN in same query)
-- ========================================================================
-- PURPOSE: Verify that mutation clauses (SET, REMOVE, MERGE) can be
--          combined with RETURN in a single Cypher query, returning
--          the post-mutation state of matched entities.
-- COVERS:  SET+RETURN, REMOVE+RETURN, MERGE+RETURN, parameterized
-- ========================================================================

.load ./build/graphqlite

SELECT '=== Test 35: Mutation + RETURN ===' as test_section;

-- ========================================================================
-- SECTION 1: SET + RETURN
-- ========================================================================
SELECT '=== Section 1: SET + RETURN ===' as section;

SELECT 'Test 1.1 - SET single property + RETURN:' as test_name;
SELECT cypher('CREATE (n:SetRet {name: "Alice", age: 30})') as setup;
SELECT cypher('MATCH (n:SetRet {name: "Alice"}) SET n.score = 100 RETURN n.score') as result;
-- Expected: [{"n.score": 100}]

SELECT 'Test 1.2 - SET multiple properties + RETURN:' as test_name;
SELECT cypher('MATCH (n:SetRet {name: "Alice"}) SET n.city = "NYC", n.active = true RETURN n.city, n.active') as result;
-- Expected: [{"n.city": "NYC", "n.active": "true"}]

SELECT 'Test 1.3 - SET bulk merge + RETURN:' as test_name;
SELECT cypher('CREATE (n:SetRet2 {name: "Bob", age: 25})') as setup;
SELECT cypher('MATCH (n:SetRet2 {name: "Bob"}) SET n += {role: "admin", level: 5} RETURN n.name, n.role, n.level') as result;
-- Expected: [{"n.name": "Bob", "n.role": "admin", "n.level": 5}]

SELECT 'Test 1.4 - SET bulk replace + RETURN:' as test_name;
SELECT cypher('CREATE (n:SetRet3 {name: "Carol", age: 28, city: "LA"})') as setup;
SELECT cypher('MATCH (n:SetRet3 {name: "Carol"}) SET n = {name: "Carol", updated: true} RETURN n.name, n.updated, n.age') as result;
-- Expected: name="Carol", updated="true", age=NULL (replaced)

SELECT 'Test 1.5 - SET + RETURN with alias:' as test_name;
SELECT cypher('MATCH (n:SetRet {name: "Alice"}) SET n.rank = 1 RETURN n.rank AS rank, n.name AS name') as result;
-- Expected: [{"rank": 1, "name": "Alice"}]

-- ========================================================================
-- SECTION 2: SET + RETURN with parameters
-- ========================================================================
SELECT '=== Section 2: Parameterized SET + RETURN ===' as section;

SELECT 'Test 2.1 - Parameterized WHERE + SET + RETURN:' as test_name;
SELECT cypher('CREATE (n:ParamRet {name: "Dave", age: 35})') as setup;
SELECT cypher('MATCH (n:ParamRet) WHERE n.name = $name SET n.verified = true RETURN n.verified', '{"name": "Dave"}') as result;
-- Expected: [{"n.verified": "true"}]

SELECT 'Test 2.2 - Parameterized SET value + RETURN:' as test_name;
SELECT cypher('MATCH (n:ParamRet) WHERE n.name = $name SET n.tag = $tag RETURN n.tag', '{"name": "Dave", "tag": "vip"}') as result;
-- Expected: [{"n.tag": "vip"}]

-- ========================================================================
-- SECTION 3: REMOVE + RETURN
-- ========================================================================
SELECT '=== Section 3: REMOVE + RETURN ===' as section;

SELECT 'Test 3.1 - REMOVE property + RETURN:' as test_name;
SELECT cypher('CREATE (n:RemRet {name: "Eve", age: 28, temp: "delete_me"})') as setup;
SELECT cypher('MATCH (n:RemRet {name: "Eve"}) REMOVE n.temp RETURN n.name, n.temp') as result;
-- Expected: name="Eve", temp=NULL

SELECT 'Test 3.2 - REMOVE label + RETURN:' as test_name;
SELECT cypher('CREATE (n:RemRet2:Extra {name: "Frank"})') as setup;
SELECT cypher('MATCH (n:RemRet2 {name: "Frank"}) REMOVE n:Extra RETURN n.name, labels(n)') as result;
-- Expected: name="Frank", labels without "Extra"

-- ========================================================================
-- SECTION 4: Edge SET + RETURN
-- ========================================================================
SELECT '=== Section 4: Edge SET + RETURN ===' as section;

SELECT 'Test 4.1 - SET edge property + RETURN:' as test_name;
SELECT cypher('CREATE (a:EdgeRet {name: "A"}), (b:EdgeRet {name: "B"})') as setup;
SELECT cypher('MATCH (a:EdgeRet {name: "A"}), (b:EdgeRet {name: "B"}) CREATE (a)-[:KNOWS {since: 2020}]->(b)') as setup2;
SELECT cypher('MATCH (a:EdgeRet)-[r:KNOWS]->(b:EdgeRet) SET r.strength = 0.9 RETURN r.since, r.strength') as result;
-- Expected: since=2020, strength=0.9

-- ========================================================================
-- SECTION 5: Multiple rows SET + RETURN
-- ========================================================================
SELECT '=== Section 5: Multiple rows ===' as section;

SELECT 'Test 5.1 - SET on multiple matched nodes + RETURN:' as test_name;
SELECT cypher('CREATE (n:MultiRet {name: "X", val: 1})') as setup1;
SELECT cypher('CREATE (n:MultiRet {name: "Y", val: 2})') as setup2;
SELECT cypher('CREATE (n:MultiRet {name: "Z", val: 3})') as setup3;
SELECT cypher('MATCH (n:MultiRet) SET n.processed = true RETURN n.name, n.processed ORDER BY n.name') as result;
-- Expected: 3 rows, all with processed=true

SELECT '=== Test 35 Complete ===' as test_section;
