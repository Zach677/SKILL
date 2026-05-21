#!/usr/bin/env bash
# Print the absolute path to the SKILL repo.
# Reads `skill_repo_dir` from ~/.config/zach-skills/config.json first, then
# the upstream ~/.config/innei-skills/config.json; falls back to Zach-Skills.
# Expands a leading ~ to $HOME.
set -euo pipefail

ZACH_CFG="${XDG_CONFIG_HOME:-$HOME/.config}/zach-skills/config.json"
INNEI_CFG="${XDG_CONFIG_HOME:-$HOME/.config}/innei-skills/config.json"
DIR=""
for CFG in "$ZACH_CFG" "$INNEI_CFG"; do
  if [ -f "$CFG" ] && command -v jq >/dev/null 2>&1; then
    DIR="$(jq -r '.skill_repo_dir // empty' "$CFG" 2>/dev/null || true)"
    [ -z "$DIR" ] || break
  fi
done
DIR="${DIR:-/Users/star/Developer/zach-repo/Zach-Skills}"
DIR="${DIR/#\~/$HOME}"
echo "$DIR"
