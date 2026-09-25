'use strict';

const http = require('node:http');

// In-memory data so the demo runs without a database.
const orders = new Map([
  ['1001', { id: '1001', customerId: 'c-1', item: 'Mechanical keyboard', total: 49.99 }],
  ['1002', { id: '1002', customerId: 'c-2', item: '27-inch monitor', total: 189.0 }],
  ['1003', { id: '1003', customerId: 'c-1', item: 'USB-C dock', total: 79.5 }],
]);

function send(res, status, body) {
  const json = JSON.stringify(body);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(json),
    'Cache-Control': 'no-store',
    'X-Content-Type-Options': 'nosniff',
  });
  res.end(json);
}

// Demo only: a real service would read the customer from a verified session
// or token, never from a header the caller controls.
function customerFrom(req) {
  const value = req.headers['x-customer-id'];
  return typeof value === 'string' && /^c-\d{1,10}$/.test(value) ? value : null;
}

function handle(req, res) {
  const { pathname } = new URL(req.url, 'http://localhost');

  if (pathname === '/healthz') {
    return send(res, 200, { status: 'ok' });
  }
  if (req.method !== 'GET') {
    return send(res, 405, { error: 'method not allowed' });
  }

  if (pathname === '/orders') {
    const customerId = customerFrom(req);
    if (!customerId) return send(res, 401, { error: 'unauthenticated' });
    const mine = [...orders.values()].filter((o) => o.customerId === customerId);
    return send(res, 200, mine);
  }

  const match = pathname.match(/^\/orders\/(\d{1,10})$/);
  if (match) {
    const customerId = customerFrom(req);
    if (!customerId) return send(res, 401, { error: 'unauthenticated' });
    const order = orders.get(match[1]);
    // Ownership check (the threat-model slide's IDOR example). "Missing" and
    // "not yours" return the same 404, so order IDs can't be probed.
    if (!order || order.customerId !== customerId) {
      return send(res, 404, { error: 'not found' });
    }
    return send(res, 200, order);
  }

  return send(res, 404, { error: 'not found' });
}

function createServer() {
  const server = http.createServer(handle);
  server.headersTimeout = 10_000;
  server.requestTimeout = 15_000;
  return server;
}

module.exports = { createServer };
