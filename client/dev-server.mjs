import * as http from "node:http";
import elmWatch from "elm-watch";

const BACKEND_PORT = 3000;

elmWatch(process.argv.slice(2), {
  createServer: ({ onRequest, onUpgrade }) =>
    http
      .createServer((request, response) => {
        if (request.url.startsWith("/api/")) {
          localhostProxy(request, response, BACKEND_PORT);
        } else {
          onRequest(request, response);
        }
      })
      .on("upgrade", (request, socket, head) => {
        // The backend websocket lives under /api/. Everything else is
        // elm-watch's own hot-reload socket.
        if (request.url.startsWith("/api/")) {
          upgradeProxy(request, socket, head, BACKEND_PORT);
        } else {
          onUpgrade(request, socket, head);
        }
      }),
})
  .then((exitCode) => process.exit(exitCode))
  .catch((error) => {
    console.error("Unexpected elm-watch error:", error);
  });

function localhostProxy(request, response, port) {
  const options = {
    hostname: "127.0.0.1",
    port,
    path: request.url,
    method: request.method,
    headers: request.headers,
  };

  const proxyRequest = http.request(options, (proxyResponse) => {
    response.writeHead(proxyResponse.statusCode, proxyResponse.headers);
    proxyResponse.pipe(response, { end: true });
  });

  proxyRequest.on("error", (error) => {
    response.writeHead(503);
    response.end(
      `Failed to proxy to localhost:${port}. Is the server running?\n\n${error.stack}`,
    );
  });

  request.pipe(proxyRequest, { end: true });
}

function upgradeProxy(request, socket, head, port) {
  const proxyRequest = http.request({
    hostname: "127.0.0.1",
    port,
    path: request.url,
    method: request.method,
    headers: request.headers,
  });

  proxyRequest.on("upgrade", (proxyResponse, proxySocket, proxyHead) => {
    const headers = Object.entries(proxyResponse.headers)
      .map(([key, value]) => `${key}: ${value}`)
      .join("\r\n");
    socket.write(`HTTP/1.1 101 Switching Protocols\r\n${headers}\r\n\r\n`);

    if (proxyHead && proxyHead.length) proxySocket.unshift(proxyHead);
    proxySocket.pipe(socket);
    socket.pipe(proxySocket);

    proxySocket.on("error", () => socket.destroy());
    socket.on("error", () => proxySocket.destroy());
  });

  proxyRequest.on("error", () => socket.destroy());
  proxyRequest.end();
}
