'use strict';

const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { createServer } = require('../src/app');

let server;
let base;

before(async () => {
  server = createServer();
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  base = `http://127.0.0.1:${server.address().port}`;
});

after(() => new Promise((resolve) => server.close(resolve)));

const get = (path, customer) =>
  fetch(base + path, { headers: customer ? { 'x-customer-id': customer } : {} });

test('health check responds', async () => {
  const res = await get('/healthz');
  assert.equal(res.status, 200);
});

test('orders require a customer', async () => {
  assert.equal((await get('/orders')).status, 401);
});

test('a customer only sees their own orders', async () => {
  const body = await (await get('/orders', 'c-1')).json();
  assert.ok(body.length > 0);
  assert.ok(body.every((o) => o.customerId === 'c-1'));
});

test("a customer cannot read another customer's order (IDOR)", async () => {
  assert.equal((await get('/orders/1002', 'c-1')).status, 404);
  assert.equal((await get('/orders/1002', 'c-2')).status, 200);
});

test('malformed customer IDs are rejected', async () => {
  assert.equal((await get('/orders', "c-1' OR 1=1")).status, 401);
});
