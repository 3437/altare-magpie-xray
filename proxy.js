// Single-port path router (adapted from the proven Abasthan proxy-path-aware.js).
// Listens on $PORT (Altare sets SERVER_PORT) and pipes raw TCP by the first
// HTTP request line's path:
//   /v1/*            -> magpie gateway  (127.0.0.1:3425)
//   /<VMESS_UUID>    -> Xray VMess     (127.0.0.1:3000)
//   /<VLESS_UUID>    -> Xray VLESS     (127.0.0.1:3001)
//   everything else  -> magpie Web     (127.0.0.1:3430)
// Raw TCP piping keeps WebSocket upgrades and SSE streams intact; the Altare
// edge terminates TLS and speaks HTTP/1.1 to this port.
const net = require("net");

const PORT = parseInt(process.env.PORT || process.env.SERVER_PORT || "8080", 10);
const VMESS_PATH = "/" + (process.env.VMESS_UUID || "");
const VLESS_PATH = "/" + (process.env.VLESS_UUID || "");

function route(path) {
  if (path.startsWith("/v1/") || path === "/v1") return 3425;
  if (VMESS_PATH.length > 1 && path.startsWith(VMESS_PATH)) return 3000;
  if (VLESS_PATH.length > 1 && path.startsWith(VLESS_PATH)) return 3001;
  return 3430;
}

const server = net.createServer((s) => {
  let decided = false;
  let buf = Buffer.alloc(0);
  const timer = setTimeout(() => decide(3430), 5000);
  function decide(port) {
    if (decided) return;
    decided = true;
    clearTimeout(timer);
    s.removeListener("data", onData);
    const t = net.connect(port, "127.0.0.1");
    t.on("error", () => s.destroy());
    s.on("error", () => t.destroy());
    if (buf.length) t.write(buf);
    s.pipe(t);
    t.pipe(s);
  }
  function onData(chunk) {
    buf = Buffer.concat([buf, chunk]);
    const end = buf.indexOf("\r\n");
    if (end === -1) {
      if (buf.length > 4096) decide(3430);
      return;
    }
    const line = buf.slice(0, end).toString("ascii");
    const m = line.match(/^[A-Z]+ (\S+) /);
    decide(m ? route(m[1]) : 3430);
  }
  s.on("data", onData);
  s.on("error", () => clearTimeout(timer));
});

server.listen(PORT, "0.0.0.0", () =>
  console.log(`[proxy] listening on ${PORT} -> /v1:3425 vmess:3000 vless:3001 web:3430`)
);
