# altare-magpie-xray

Single-container stack for one Altare Docker app (Singapore): magpie Web UI +
OpenAI-compatible gateway, Xray (VMess + VLESS over WebSocket), and a
single-port path router (`proxy.js`) in front of them.

## How it routes

`proxy.js` listens on `$PORT` (Altare's `SERVER_PORT`) and pipes raw TCP by
the first request path:

| Path | Target |
| --- | --- |
| `/v1/*` | magpie gateway, 127.0.0.1:3425 |
| `/<VMESS_UUID>` | Xray VMess/WS, 127.0.0.1:3000 |
| `/<VLESS_UUID>` | Xray VLESS/WS, 127.0.0.1:3001 |
| anything else | magpie Web UI, 127.0.0.1:3430 |

## Required environment variables (set in the Altare console)

- `VMESS_UUID` — UUID for the VMess inbound
- `VLESS_UUID` — UUID for the VLESS inbound
- `MAGPIE_WEB_KEY` — magpie Web login key (16+ chars, letters/digits/`-._~`)
- `MAGPIE_WEB_URL` — optional, `https://<public https name>` so magpie
  prints the right link behind the reverse proxy

## Persistence

magpie's data lives under `$HOME`, which `start.sh` points at `/data` —
Altare's Data folder, the only path kept across redeploys. The Xray config
is regenerated from the environment on every start.

## Image

GitHub Actions builds this Dockerfile and pushes
`ghcr.io/<owner>/altare-magpie-xray:latest` on every push to `main`.
