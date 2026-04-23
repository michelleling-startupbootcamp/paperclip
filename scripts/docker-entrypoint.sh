#!/bin/sh
set -e

PUID=${USER_UID:-1000}
PGID=${USER_GID:-1000}

changed=0
if [ "$(id -u node)" -ne "$PUID" ]; then
    echo "Updating node UID to $PUID"
    usermod -o -u "$PUID" node
    changed=1
fi
if [ "$(id -g node)" -ne "$PGID" ]; then
    echo "Updating node GID to $PGID"
    groupmod -o -g "$PGID" node
    usermod -g "$PGID" node
    changed=1
fi
if [ "$changed" = "1" ]; then
    chown -R node:node /paperclip
fi

if [ ! -f /paperclip/adapter-plugins.json ]; then
    mkdir -p /paperclip
    echo '{"plugins":{"hermes_local":{"package":"@henkey/hermes-paperclip-adapter","type":"hermes_local"}}}' > /paperclip/adapter-plugins.json
    chown node:node /paperclip/adapter-plugins.json
    echo "Created adapter-plugins.json"
fi

# Configure Hermes to call Nous inference directly as a custom OpenAI-compatible
# provider. This avoids the Nous Portal OAuth session requirement entirely.
# TOOL_GATEWAY_USER_TOKEN (set in Railway env) handles managed tool auth.
if [ -n "$NOUS_API_KEY" ]; then
    echo "Configuring Hermes: custom provider -> Nous inference API..."
    /usr/local/bin/hermes config set model.provider custom
    /usr/local/bin/hermes config set model.base_url https://inference-api.nousresearch.com/v1
    /usr/local/bin/hermes config set model.api_key "$NOUS_API_KEY"
    /usr/local/bin/hermes config set model.default hermes-3-70b
    chmod -R a+rwX /opt/hermes-root/.hermes 2>/dev/null || true
    echo "Hermes provider configured."
fi

exec gosu node "$@"
