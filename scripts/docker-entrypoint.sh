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

exec gosu node "$@"
