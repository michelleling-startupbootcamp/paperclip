#!/bin/sh
set -e

PUID=${USER_UID:-1000}
PGID=${USER_GID:-1000}

changed=0
if [ "$(id -u node)" -ne "$PUID" ]; then
    usermod -o -u "$PUID" node
    changed=1
fi
if [ "$(id -g node)" -ne "$PGID" ]; then
    groupmod -o -g "$PGID" node
    usermod -g "$PGID" node
    changed=1
fi
if [ "$changed" = "1" ]; then
    chown -R node:node /paperclip
fi

if [ ! -f /paperclip/adapter-plugins.json ]; then
    mkdir -p /paperclip
    printf '{"plugins":{"hermes_local":{"package":"@henkey/hermes-paperclip-adapter","type":"hermes_local"}}}' > /paperclip/adapter-plugins.json
    chown node:node /paperclip/adapter-plugins.json
fi

# Write hermes config.yaml directly — no subprocess spawns, no set -e risk.
# Uses custom OpenAI-compatible provider pointing at Nous inference API.
# This bypasses the Nous Portal OAuth session requirement entirely.
if [ -n "$NOUS_API_KEY" ]; then
    mkdir -p /opt/hermes-root/.hermes
    printf "model:\n  provider: custom\n  base_url: https://inference-api.nousresearch.com/v1\n  api_key: \"%s\"\n  default: hermes-3-70b\n" "$NOUS_API_KEY" \
        > /opt/hermes-root/.hermes/config.yaml
    chmod -R a+rwX /opt/hermes-root/.hermes 2>/dev/null || true
    echo "Hermes config.yaml written (custom/Nous)."
fi

exec gosu node "$@"