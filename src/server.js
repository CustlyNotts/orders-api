'use strict';

const { createServer } = require('./app');

const port = Number(process.env.PORT || 3000);
const server = createServer();

server.listen(port, () => {
  console.log(`orders-api listening on :${port}`);
});

// Kubernetes sends SIGTERM before stopping a pod: finish in-flight requests.
for (const signal of ['SIGTERM', 'SIGINT']) {
  process.on(signal, () => {
    server.close(() => process.exit(0));
    setTimeout(() => process.exit(1), 5_000).unref();
  });
}
