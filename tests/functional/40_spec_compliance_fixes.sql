-- ========================================================================
-- Test 40: Spec Compliance Fixes
-- ========================================================================
-- PURPOSE: Regression tests for 5 Cypher spec compliance gaps fixed
--          after the #34-#55 bug-fix cycle.
-- COVERS:  COUNT null-skipping, edge WITH, CREATE functions,
--          CALL export, CALL multi-row
-- ========================================================================

.load ./build/graphqlite

SELECT '=== Test 40: Spec Compliance Fixes ===' as test_section;

-- =======================================================================
-- Bug A: COUNT(r) after OPTIONAL MATCH should skip nulls
-- =======================================================================
SELECT '=== Bug A: COUNT + OPTIONAL MATCH null-skipping ===' as section;

SELECT cypher('CREATE (a:CntNull40 {id: "x"})') as result;
SELECT cypher('CREATE (p:CntPet40 {id: "p"})') as result;
SELECT cypher('MATCH (a:CntNull40), (p:CntPet40) CREATE (a)-[:OWNS40]->(p)') as result;

SELECT 'Test A - COUNT(r) where r is null from OPTIONAL MATCH:' as test_name;
SELECT '  Expected: x | 0' as expected;
SELECT cypher('MATCH (a:CntNull40) OPTIONAL MATCH (a)-->(r:Ghost40) RETURN a.id AS aid, COUNT(r) AS cnt') as result;
-- Was BUG: cnt = 1 (json_object never returns NULL)
-- Now fixed: cnt = 0

-- =======================================================================
-- Bug B: Edge variables through WITH
-- =======================================================================
SELECT '=== Bug B: Edge variables through WITH ===' as section;

SELECT cypher('CREATE (:EW40A {id: "a"})-[:EREL40 {weight: 7}]->(:EW40B {id: "b"})') as result;

SELECT 'Test B1 - type(r) after WITH:' as test_name;
SELECT '  Expected: EREL40' as expected;
SELECT cypher('MATCH (a:EW40A)-[r:EREL40]->(b:EW40B) WITH a, b, r RETURN type(r) AS t') as result;
-- Was BUG: no such column: _with_0.r.id

SELECT 'Test B2 - r.weight after WITH:' as test_name;
SELECT '  Expected: 7' as expected;
SELECT cypher('MATCH (a:EW40A)-[r:EREL40]->(b:EW40B) WITH r RETURN r.weight AS w') as result;
-- Was BUG: no such column: _with_0.r.id

-- =======================================================================
-- Bug C: Function calls in CREATE property maps
-- =======================================================================
SELECT '=== Bug C: Functions in CREATE property maps ===' as section;

SELECT cypher('CREATE (n:FnCreate40 {upper: toUpper("hello"), lower: toLower("WORLD")})') as result;

SELECT 'Test C - Functions evaluated in CREATE:' as test_name;
SELECT '  Expected: HELLO | world' as expected;
SELECT cypher('MATCH (n:FnCreate40) RETURN n.upper, n.lower') as result;
-- Was BUG: both NULL (functions not evaluated in CREATE)

-- =======================================================================
-- Bug D: CALL subquery exports inner RETURN variables
-- =======================================================================
SELECT '=== Bug D: CALL inner RETURN export ===' as section;

SELECT cypher('CREATE (:CallExp40 {id: "ce1"})') as result;

SELECT 'Test D - inner_id visible in outer scope:' as test_name;
SELECT '  Expected: ce1 | ce1' as expected;
SELECT cypher('MATCH (a:CallExp40) CALL { WITH a RETURN a.id AS inner_id } RETURN a.id AS outer_id, inner_id') as result;
-- Was BUG: Unknown variable: inner_id

-- =======================================================================
-- Bug E: CALL subquery processes all inner MATCH rows
-- =======================================================================
SELECT '=== Bug E: CALL multi-row inner MATCH ===' as section;

SELECT cypher('CREATE (:CallCo40 {id: "co"})') as result;
SELECT cypher('CREATE (:CallDep40 {id: "d1"})') as result;
SELECT cypher('CREATE (:CallDep40 {id: "d2"})') as result;
SELECT cypher('CREATE (:CallDep40 {id: "d3"})') as result;

SELECT cypher('MATCH (c:CallCo40) CALL { WITH c MATCH (d:CallDep40) MERGE (c)-[:CHAS40]->(d) }') as result;

SELECT 'Test E - All 3 departments linked:' as test_name;
SELECT '  Expected: 3 rows' as expected;
SELECT cypher('MATCH (:CallCo40)-[:CHAS40]->(d:CallDep40) RETURN d.id ORDER BY d.id') as result;
-- Was BUG: only 1 relationship created (if instead of while)

SELECT '=== Spec Compliance Fixes Complete ===' as test_section;
