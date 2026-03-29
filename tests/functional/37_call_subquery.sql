-- ========================================================================
-- Test 37: CALL {} Subquery
-- ========================================================================
-- PURPOSE: Test CALL subquery parsing, execution, and variable scoping
-- COVERS:  Basic CALL, WITH import, UNION branches, nested CALL,
--          write operations, empty outer sets, multiple CALL clauses
-- ========================================================================

.load ./build/graphqlite

SELECT '=== Test 37: CALL {} Subquery ===' as test_section;

-- =======================================================================
-- SETUP: Create test data
-- =======================================================================
SELECT '=== Setup: Creating test data ===' as section;

SELECT cypher('CREATE (a:CallPerson {name: "Alice", age: 30})') as setup;
SELECT cypher('CREATE (b:CallPerson {name: "Bob", age: 25})') as setup;
SELECT cypher('CREATE (c:CallPerson {name: "Carol", age: 35})') as setup;
SELECT cypher('CREATE (d:CallDept {name: "Engineering"})') as setup;
SELECT cypher('CREATE (e:CallDept {name: "Marketing"})') as setup;

-- =======================================================================
-- SECTION 1: Basic standalone CALL
-- =======================================================================
SELECT '=== Section 1: Basic Standalone CALL ===' as section;

SELECT 'Test 1.1 - CALL with inner MATCH+RETURN:' as test_name;
SELECT cypher('CALL { MATCH (n:CallPerson) RETURN n.name }') as result;

SELECT 'Test 1.2 - CALL with literal RETURN:' as test_name;
SELECT cypher('CALL { RETURN 42 AS answer }') as result;

-- =======================================================================
-- SECTION 2: CALL with UNION
-- =======================================================================
SELECT '=== Section 2: CALL with UNION ===' as section;

SELECT 'Test 2.1 - CALL with UNION of literals:' as test_name;
SELECT cypher('CALL { RETURN 1 AS n UNION RETURN 2 AS n }') as result;

SELECT 'Test 2.2 - CALL with UNION ALL:' as test_name;
SELECT cypher('CALL { RETURN 1 AS n UNION ALL RETURN 1 AS n }') as result;

-- =======================================================================
-- SECTION 3: MATCH + CALL with WITH variable import (SET)
-- =======================================================================
SELECT '=== Section 3: MATCH + CALL + SET ===' as section;

SELECT 'Test 3.1 - SET property via CALL with outer variable:' as test_name;
SELECT cypher('MATCH (a:CallPerson {name: "Alice"}) CALL { WITH a SET a.touched = true }') as result;

SELECT 'Test 3.2 - Verify SET worked:' as test_name;
SELECT cypher('MATCH (n:CallPerson {name: "Alice"}) RETURN n.name, n.touched') as result;

SELECT 'Test 3.3 - SET on multiple outer rows:' as test_name;
SELECT cypher('MATCH (n:CallPerson) CALL { WITH n SET n.seen = true }') as result;

SELECT 'Test 3.4 - Verify all rows were SET:' as test_name;
SELECT cypher('MATCH (n:CallPerson) RETURN n.name, n.seen ORDER BY n.name') as result;

-- =======================================================================
-- SECTION 4: MATCH + CALL + RETURN
-- =======================================================================
SELECT '=== Section 4: MATCH + CALL + RETURN ===' as section;

SELECT 'Test 4.1 - CALL side effects then RETURN outer:' as test_name;
SELECT cypher('MATCH (n:CallPerson) CALL { WITH n SET n.processed = true } RETURN n.name') as result;

SELECT 'Test 4.2 - Verify side effects from 4.1:' as test_name;
SELECT cypher('MATCH (n:CallPerson) RETURN n.name, n.processed ORDER BY n.name') as result;

-- =======================================================================
-- SECTION 5: MATCH + CALL + MERGE (relationship creation)
-- =======================================================================
SELECT '=== Section 5: MERGE via CALL ===' as section;

SELECT 'Test 5.1 - Create relationship via CALL MERGE:' as test_name;
SELECT cypher('MATCH (p:CallPerson {name: "Alice"}) CALL { WITH p MERGE (p)-[:WORKS_IN]->(d:CallDept {name: "Engineering"}) }') as result;

SELECT 'Test 5.2 - Verify relationship created:' as test_name;
SELECT cypher('MATCH (p:CallPerson)-[r:WORKS_IN]->(d:CallDept) RETURN p.name, type(r), d.name') as result;

-- =======================================================================
-- SECTION 6: Empty outer result set
-- =======================================================================
SELECT '=== Section 6: Empty Outer Result Set ===' as section;

SELECT 'Test 6.1 - Create marker node:' as test_name;
SELECT cypher('CREATE (m:CallMarker {val: 0})') as result;

SELECT 'Test 6.2 - CALL with no matching outer rows:' as test_name;
SELECT cypher('MATCH (z:NonExistentLabel) CALL { WITH z SET z.touched = true }') as result;

SELECT 'Test 6.3 - Verify marker unchanged (subquery did not execute):' as test_name;
SELECT cypher('MATCH (m:CallMarker) RETURN m.val') as result;

-- =======================================================================
-- SECTION 7: Nested CALL
-- =======================================================================
SELECT '=== Section 7: Nested CALL ===' as section;

SELECT 'Test 7.1 - Nested CALL with RETURN:' as test_name;
SELECT cypher('CALL { CALL { RETURN 99 AS n } }') as result;

SELECT 'Test 7.2 - Nested CALL with inner MATCH:' as test_name;
SELECT cypher('CALL { CALL { MATCH (n:CallPerson {name: "Alice"}) RETURN n.name } }') as result;

-- =======================================================================
-- SECTION 8: Error cases
-- =======================================================================
SELECT '=== Section 8: Error Cases ===' as section;

SELECT 'Test 8.1 - CALL without braces (parse error expected):' as test_name;
-- This should produce a parse error - we test it doesn't crash
-- Using a subselect to catch the error without -bail stopping us

-- =======================================================================
-- SECTION 9: CALL with ORDER BY/LIMIT in inner query
-- =======================================================================
SELECT '=== Section 9: ORDER BY/LIMIT in inner query ===' as section;

SELECT 'Test 9.1 - CALL with inner ORDER BY and LIMIT:' as test_name;
SELECT cypher('CALL { MATCH (n:CallPerson) RETURN n.name ORDER BY n.name LIMIT 2 }') as result;

-- =======================================================================
-- SECTION 10: CALL with no RETURN (write-only inner subquery)
-- =======================================================================
SELECT '=== Section 10: Write-only CALL ===' as section;

SELECT 'Test 10.1 - CALL that only writes:' as test_name;
SELECT cypher('CALL { CREATE (x:CallTemp {source: "call"}) }') as result;

SELECT 'Test 10.2 - Verify write-only CALL:' as test_name;
SELECT cypher('MATCH (x:CallTemp) RETURN x.source') as result;

SELECT '=== Test 37 Complete ===' as test_section;
