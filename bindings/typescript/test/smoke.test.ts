import { test } from 'node:test';
import assert from 'node:assert/strict';

// Smoke test for the F-01 scaffolding: proves the node:test + node:assert
// runner is wired up and the package skeleton loads. Real coverage
// (connection/graph/algorithms) arrives with later elements.
test('scaffolding is in place', () => {
  assert.equal(1 + 1, 2);
});

test('index module has no runtime exports yet', async () => {
  const mod = await import('../src/index.ts');
  assert.deepEqual(Object.keys(mod), []);
});
