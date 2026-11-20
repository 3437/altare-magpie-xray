# magpie + Xray + proxy.js in one Altare Docker app (Singapore).
# Single port (SERVER_PORT): proxy.js routes /v1 -> magpie gateway (3425),
# /<uuid> -> Xray (3000/3001), everything else -> magpie Web (3430).
FROM node:22-bookworm-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends curl unzip ca-certificates \
  && rm -rf /var/lib/apt/lists/*

# Xray (VMess/VLESS)
RUN curl -fsSL -o /tmp/xray.zip \
      https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip \
  && unzip -q /tmp/xray.zip -d /tmp/xray-bin xray \
  && install -m 755 /tmp/xray-bin/xray /usr/local/bin/xray \
  && rm -rf /tmp/xray.zip /tmp/xray-bin

# magpie CLI (terminal-only build; `web --lan --no-open` serves Web UI + gateway)
RUN curl -fsSL -o /usr/local/bin/magpie \
      https://github.com/yetone/magpie-releases/releases/latest/download/magpie-cli-linux-amd64 \
  && chmod 755 /usr/local/bin/magpie

WORKDIR /app
COPY proxy.js start.sh ./
RUN chmod +x start.sh

CMD ["./start.sh"]
