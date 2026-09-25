#!/usr/bin/env bash
# Boot the assembled release against the REAL mesh (public demo stations),
# the same way the twins were verified locally. The realm material is public
# fleet config; the identity key is local scratch. Without the operator's
# grant the claim is refused -- the node still boots, /health answers, and
# the store + admin UI run, which is exactly the pre-grant state the
# deployment checklist describes.
set -euo pipefail
cd "$(dirname "$0")/.."

export RELX_REPLACE_OS_VARS=true
export MCL_REALM=abb81b5a614b63551b400b810648c0c8a78efad845442630c94b46cc95d2fcd1
export MCL_REALM_KEY="$(grep '^MCL_REALM_KEY=' /home/rl/work/github.com/macula-io/macula-fleet/edge/beam03.lab/mcl-bookclub-config.env | cut -d= -f2)"
export MACULA_STATION_SEEDS=station-de-falkenstein.macula.io:4433,station-fi-helsinki.macula.io:4433,station-de-frankfurt.macula.io:4433
export MACULA_STATION_NODE_IDS=00df68247d119685f94030afdb203ab7a2a105fb6093a964dbf0509a57e86435,004d1f470097ccf8826ce291900e882fdb1f20375e53901facaec0f23eb4efd8,00cd0008ec2e72b6572b7bf6fc8b048d7fe83993faf1fc544370f2bc1eb71f85
export MCL_COOKIE=mcl_bookclub_gleam
export MCL_NODE_NAME=mcl_bookclub_gleam
export MCL_NODE_HOST=127.0.0.1
export MCL_HEALTH_PORT=8455
export MCL_ADMIN_PORT=8490
export MCL_IDENTITY_KEY_PATH="${MCL_IDENTITY_KEY_PATH:-/tmp/gleam-boot/secrets/identity.key}"
export MCL_DATA_DIR="${MCL_DATA_DIR:-/tmp/gleam-boot/data}"
export MCL_SERVICE_NAME=mcl-bookclub-gleam

mkdir -p "$(dirname "$MCL_IDENTITY_KEY_PATH")" "$MCL_DATA_DIR"
exec _build/release/mcl_bookclub_gleam/bin/mcl_bookclub_gleam foreground
