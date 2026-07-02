#!/bin/bash
# SessionStart hook: make GUT tests + gdlint/gdformat runnable in Claude Code
# web sessions. Installs the Godot 4.7 headless binary and gdtoolkit.
# Idempotent; only runs in remote (web) environments.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# gdtoolkit (gdformat / gdlint)
if ! command -v gdlint >/dev/null 2>&1; then
  pip3 install --quiet gdtoolkit
fi

# Godot 4.7 headless-capable binary
if ! command -v godot >/dev/null 2>&1; then
  TMP=$(mktemp -d)
  # Official download redirector (GitHub release downloads are blocked in this environment)
  curl -sSL --retry 3 --max-time 600 -o "$TMP/godot.zip" \
    "https://downloads.godotengine.org/?version=4.7&flavor=stable&slug=linux.x86_64.zip&platform=linux.64"
  unzip -q -o "$TMP/godot.zip" -d "$TMP"
  mv "$TMP/Godot_v4.7-stable_linux.x86_64" /usr/local/bin/godot
  chmod +x /usr/local/bin/godot
  rm -rf "$TMP"
fi

godot --version
gdlint --version
