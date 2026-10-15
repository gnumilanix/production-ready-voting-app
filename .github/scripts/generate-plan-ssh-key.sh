#!/usr/bin/env bash
set -euo pipefail

key_dir="$(mktemp -d)"
trap 'rm -rf "$key_dir"' EXIT

ssh-keygen -q -t ed25519 -N '' -C 'dependabot-plan-only' -f "$key_dir/key"
printf 'TF_VAR_jump_server_public_key=%s\n' "$(cat "$key_dir/key.pub")" >> "$GITHUB_ENV"
