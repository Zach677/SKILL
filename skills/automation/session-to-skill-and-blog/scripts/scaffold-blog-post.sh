#!/usr/bin/env bash
# Create a zaxh.org MDX draft under data/posts/ that links back to the
# newly-pushed skill. The script writes a local draft only; publishing remains
# the normal blog git/deploy flow.
#
# Usage:
#   scaffold-blog-post.sh <domain> <skill-name> <slug> "<title>" "<description>" [tag1,tag2]
set -euo pipefail

if [ $# -lt 5 ] || [ $# -gt 6 ]; then
  echo "usage: $(basename "$0") <domain> <skill-name> <slug> \"<title>\" \"<description>\" [tag1,tag2]" >&2
  exit 2
fi

DOMAIN="$1"
SKILL_NAME="$2"
SLUG="$3"
TITLE="$4"
DESCRIPTION="$5"
TAGS_CSV="${6:-AI,Skills}"

case "$DOMAIN" in
  infrastructure|automation|writing|research|content) ;;
  *) echo "error: invalid domain '$DOMAIN' (expected one of: infrastructure|automation|writing|research|content)" >&2; exit 2 ;;
esac

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BLOG="$(bash "$HERE/resolve-blog-repo.sh")"
POSTS_DIR="$BLOG/data/posts"
POST="$POSTS_DIR/$SLUG.mdx"
USER_CFG="${XDG_CONFIG_HOME:-$HOME/.config}/zach-skills/config.json"

[ -d "$BLOG" ] || { echo "error: blog repo not found: $BLOG" >&2; exit 1; }
[ -e "$POST" ] && { echo "error: post already exists: $POST" >&2; exit 1; }

mkdir -p "$POSTS_DIR"

python3 - "$POST" "$DOMAIN" "$SKILL_NAME" "$SLUG" "$TITLE" "$DESCRIPTION" "$TAGS_CSV" "$USER_CFG" <<'PY'
import datetime as dt
import json
import pathlib
import sys

post, domain, skill_name, slug, title, description, tags_csv, user_cfg = sys.argv[1:]
repo_url = "https://github.com/Zach677/Zach-Skills"
cfg = pathlib.Path(user_cfg)
if cfg.exists():
    try:
        repo_url = json.loads(cfg.read_text()).get("skill_repo_url") or repo_url
    except Exception:
        pass
skill_url = f"{repo_url.rstrip('/')}/tree/main/skills/{domain}/{skill_name}"
date = dt.datetime.now(dt.timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")
tags = [tag.strip() for tag in tags_csv.split(",") if tag.strip()]
tag_expr = ", ".join(repr(tag) for tag in tags)

body = f"""export const metadata = {{
  title: {title!r},
  description: {description!r},
  date: {date!r},
  tags: [{tag_expr}],
}}

> Related skill: [{skill_name}]({skill_url})

## Context

Write the task background here: what happened in the original session, why it
was worth keeping, and what changed after the workflow was extracted.

## What the skill captures

- The reusable operating procedure
- The non-obvious pitfalls
- The verification commands or checks
- The boundaries where this should not be reused

## Notes from the implementation

Use this section for the narrative. Keep code samples short; link back to the
skill for the durable workflow.

---

The reusable workflow is kept in [{skill_name}]({skill_url}).
"""

pathlib.Path(post).write_text(body)
print(post)
PY

if git -C "$BLOG" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git -C "$BLOG" add "$POST"
fi

cat <<EOF

drafted: $POST
next steps:
  1. fill in the MDX body
  2. cd "$BLOG" && pnpm build
  3. commit the blog post through the normal blog workflow
EOF
