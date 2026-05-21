#!/usr/bin/env bash
# Print the absolute path to the zaxh.org blog repo.
# Reads `blog_repo_dir` from ~/.config/zach-skills/config.json; falls back to
# /Users/star/Developer/zach-repo/zaxh.org. Expands a leading ~ to $HOME.
set -euo pipefail

CFG="${XDG_CONFIG_HOME:-$HOME/.config}/zach-skills/config.json"
DIR=""
if [ -f "$CFG" ] && command -v jq >/dev/null 2>&1; then
  DIR="$(jq -r '.blog_repo_dir // empty' "$CFG" 2>/dev/null || true)"
fi
DIR="${DIR:-/Users/star/Developer/zach-repo/zaxh.org}"
DIR="${DIR/#\~/$HOME}"
echo "$DIR"
