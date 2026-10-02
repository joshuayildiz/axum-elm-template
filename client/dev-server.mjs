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
      .on("upgrade", onUpgrade),
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
