#!/bin/sh
set -e

# Capture runtime UID/GID from environment variables, defaulting to 1000
PUID=${USER_UID:-1000}
PGID=${USER_GID:-1000}

# Adjust the node user's UID/GID if they differ from the runtime request
# and fix volume ownership only when a remap is needed
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

# Ensure adapter-plugins.json exists for Hermes external adapter
if [ ! -f /paperclip/adapter-plugins.json ]; then
    mkdir -p /paperclip
    echo '{"plugins":{"hermes_local":{"package":"@henkey/hermes-paperclip-adapter","type":"hermes_local"}}}' > /paperclip/adapter-plugins.json
    chown node:node /paperclip/adapter-plugins.json
    echo "Created adapter-plugins.json"
fi

# Configure hermes to use the Nous inference API as a custom OpenAI-compatible
# endpoint. The hermes "nous" provider requires OAuth (device code flow), but
# the Nous inference API (inference-api.nousresearch.com/v1) is OpenAI-compatible
# and accepts a plain API key. We use provider=custom to bypass the OAuth check.
NOUS_MARKER=/opt/hermes-root/.hermes/.nous-config-done
if [ -n "$NOUS_API_KEY" ] && [ ! -f "$NOUS_MARKER" ]; then
    echo "Configuring Hermes for Nous inference API (custom OpenAI-compatible endpoint)..."
    export HOME=/opt/hermes-root
    if /usr/local/bin/hermes config set model.provider custom \
    && /usr/local/bin/hermes config set model.base_url https://inference-api.nousresearch.com/v1 \
    && /usr/local/bin/hermes config set model.api_key "$NOUS_API_KEY" \
    && /usr/local/bin/hermes config set model.default hermes-3-70b; then
        touch "$NOUS_MARKER"
        chmod -R a+rwX /opt/hermes-root/.hermes 2>/dev/null || true
        echo "Hermes configured for Nous inference API."
    else
        echo "WARNING: Hermes configuration failed; hermes tasks may fail."
    fi
fi

exec gosu node "$@"
