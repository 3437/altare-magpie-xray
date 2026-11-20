#!/bin/bash
# Entry script: Xray (VMess 3000 + VLESS 3001) + magpie web/gateway + proxy.js.
# Env required: VMESS_UUID, VLESS_UUID, MAGPIE_WEB_KEY (16+ chars).
# Optional: MAGPIE_WEB_URL=https://<public https name> (prints the right link).
set -euo pipefail

: "${VMESS_UUID:?need VMESS_UUID}"
: "${VLESS_UUID:?need VLESS_UUID}"
: "${MAGPIE_WEB_KEY:?need MAGPIE_WEB_KEY}"

mkdir -p /data /data/log

cat > /data/xray.json <<EOF
{
  "log": {"loglevel": "warning"},
  "inbounds": [{
    "port": 3000, "listen": "127.0.0.1", "protocol": "vmess",
    "settings": {"clients": [{"id": "$VMESS_UUID", "alterId": 0}]},
    "streamSettings": {"network": "ws", "wsSettings": {"path": "/$VMESS_UUID"}}
  }, {
    "port": 3001, "listen": "127.0.0.1", "protocol": "vless",
    "settings": {"clients": [{"id": "$VLESS_UUID"}], "decryption": "none"},
    "streamSettings": {"network": "ws", "wsSettings": {"path": "/$VLESS_UUID"}}
  }],
  "outbounds": [{"protocol": "freedom", "tag": "direct"}]
}
EOF

/usr/local/bin/xray run -c /data/xray.json > /data/log/xray.log 2>&1 &
# magpie keeps providers/keys under $HOME; point it at /data so it survives
# redeploys (Altare only preserves the Data folder, default /data).
export HOME=/data
/usr/local/bin/magpie web --lan --no-open > /data/log/magpie.log 2>&1 &

# Wait for the backends to listen before proxying (Altare rolls back if the
# app port is not listening ~90s after build; proxy.js is the app port).
for i in $(seq 1 30); do
  sleep 1
  (exec 3<>/dev/tcp/127.0.0.1/3425) 2>/dev/null && (exec 3<>/dev/tcp/127.0.0.1/3430) 2>/dev/null && break
done
echo "[start] backends up, starting proxy"
exec node /app/proxy.js
