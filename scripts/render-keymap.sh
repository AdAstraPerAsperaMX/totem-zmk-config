#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
keymap_cmd="${KEYMAP_CMD:-keymap}"

if ! command -v "$keymap_cmd" >/dev/null 2>&1; then
  echo "error: '$keymap_cmd' is not installed or not on PATH" >&2
  exit 1
fi

"$keymap_cmd" -c "$repo_root/keymap-drawer-config.yaml" parse \
  -z "$repo_root/config/totem.keymap" \
  -o "$repo_root/keymap-drawer/totem.yaml"

"$keymap_cmd" -c "$repo_root/keymap-drawer-config.yaml" draw \
  "$repo_root/keymap-drawer/totem.yaml" \
  -o "$repo_root/keymap-drawer/totem.svg"

cp "$repo_root/keymap-drawer/totem.svg" "$repo_root/totem-keymap.svg"

