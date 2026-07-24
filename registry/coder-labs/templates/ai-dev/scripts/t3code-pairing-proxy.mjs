import { execFile } from "node:child_process";
import http from "node:http";
import net from "node:net";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);
const listenPort = Number(process.env.T3CODE_PROXY_PORT ?? "3774");
const targetPort = Number(process.env.T3CODE_TARGET_PORT ?? "3773");
const t3Binary = process.env.T3CODE_BIN;
const dataDirectory = process.env.T3CODE_DATA_DIR;

if (!t3Binary || !dataDirectory) {
  throw new Error("T3CODE_BIN and T3CODE_DATA_DIR are required");
}

async function createPairingToken() {
  const { stdout } = await execFileAsync(
    t3Binary,
    [
      "auth",
      "pairing",
      "create",
      "--ttl",
      "30d",
      "--label",
      "Coder browser app",
      "--base-dir",
      dataDirectory,
      "--json",
    ],
    {
      encoding: "utf8",
      maxBuffer: 1024 * 1024,
    },
  );
  const result = JSON.parse(stdout);

  if (typeof result.credential !== "string" || result.credential.length === 0) {
    throw new Error("T3 Code did not return a pairing credential");
  }

  return result.credential;
}

function proxyRequest(request, response) {
  const headers = {
    ...request.headers,
    host: "127.0.0.1:" + targetPort,
  };
  const upstream = http.request(
    {
      hostname: "127.0.0.1",
      port: targetPort,
      method: request.method,
      path: request.url,
      headers,
    },
    (upstreamResponse) => {
      const responseHeaders = { ...upstreamResponse.headers };
      if (typeof responseHeaders.location === "string") {
        responseHeaders.location = responseHeaders.location.replace(
          "http://127.0.0.1:" + targetPort,
          "",
        );
        responseHeaders.location = responseHeaders.location.replace(
          "http://localhost:" + targetPort,
          "",
        );
      }
      response.writeHead(upstreamResponse.statusCode ?? 502, responseHeaders);
      upstreamResponse.pipe(response);
    },
  );

  upstream.on("error", (error) => {
    if (!response.headersSent) {
      response.writeHead(502, { "content-type": "text/plain" });
    }
    response.end("T3 Code upstream error: " + error.message);
  });
  request.pipe(upstream);
}

const server = http.createServer(async (request, response) => {
  if (request.url === "/__health") {
    const healthRequest = http.get(
      {
        hostname: "127.0.0.1",
        port: targetPort,
        path: "/",
        timeout: 2000,
      },
      (healthResponse) => {
        healthResponse.resume();
        response.writeHead(
          (healthResponse.statusCode ?? 500) < 500 ? 200 : 503,
          { "content-type": "text/plain" },
        );
        response.end("ok");
      },
    );
    healthRequest.on("timeout", () => healthRequest.destroy());
    healthRequest.on("error", () => {
      response.writeHead(503, { "content-type": "text/plain" });
      response.end("unhealthy");
    });
    return;
  }

  if (request.url === "/__coder_pair") {
    try {
      const credential = await createPairingToken();
      response.writeHead(302, {
        "cache-control": "no-store",
        location: "/pair#token=" + encodeURIComponent(credential),
      });
      response.end();
    } catch (error) {
      response.writeHead(500, {
        "cache-control": "no-store",
        "content-type": "text/plain",
      });
      response.end(
        "Unable to create a T3 Code pairing token: " +
          (error instanceof Error ? error.message : String(error)),
      );
    }
    return;
  }

  proxyRequest(request, response);
});

server.on("upgrade", (request, socket, head) => {
  const upstream = net.connect(targetPort, "127.0.0.1", () => {
    upstream.write(
      request.method +
        " " +
        request.url +
        " HTTP/" +
        request.httpVersion +
        "\r\n",
    );
    for (const [name, value] of Object.entries(request.headers)) {
      if (value === undefined) {
        continue;
      }
      const headerValue =
        name.toLowerCase() === "host"
          ? "127.0.0.1:" + targetPort
          : Array.isArray(value)
            ? value.join(", ")
            : value;
      upstream.write(name + ": " + headerValue + "\r\n");
    }
    upstream.write("\r\n");
    if (head.length > 0) {
      upstream.write(head);
    }
    socket.pipe(upstream).pipe(socket);
  });

  upstream.on("error", () => socket.destroy());
  socket.on("error", () => upstream.destroy());
});

server.listen(listenPort, "127.0.0.1", () => {
  process.stdout.write(
    "T3 Code pairing proxy listening on http://127.0.0.1:" + listenPort + "\n",
  );
});
