#!/usr/bin/env bash
# Scaffold a new skill in the SKILL repo: directory, stub SKILL.md,
# README row (alphabetical inside the domain table), and the two flat
# symlinks required by the pre-commit hook. Stages everything with `git add`
# but does NOT commit — the agent fills in SKILL.md, then commits.
#
# Usage: scaffold-skill.sh <domain> <skill-name> "<one-line purpose>"
#   domain ∈ infrastructure | automation | writing | research | content
set -euo pipefail

if [ $# -ne 3 ]; then
  echo "usage: $(basename "$0") <domain> <skill-name> \"<one-line purpose>\"" >&2
  exit 2
fi

DOMAIN="$1"
NAME="$2"
PURPOSE="$3"

case "$DOMAIN" in
  infrastructure|automation|writing|research|content) ;;
  *) echo "error: invalid domain '$DOMAIN' (expected one of: infrastructure|automation|writing|research|content)" >&2; exit 2 ;;
esac

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(bash "$HERE/resolve-skill-repo.sh")"
TARGET="$REPO/skills/$DOMAIN/$NAME"

[ "$(basename "$REPO")" != "Zach-Skills" ] || [[ "$NAME" == zach-* ]] || {
  echo "error: Zach-Skills requires skill names to use the zach- prefix" >&2
  exit 2
}

[ -e "$TARGET" ] && { echo "error: $TARGET already exists" >&2; exit 1; }

mkdir -p "$TARGET/references" "$TARGET/scripts"

cat > "$TARGET/SKILL.md" <<EOF
---
name: $NAME
description: >
  Use when … (fill in: trigger phrases, conditions; ≤ 500 chars).
metadata:
  author: zach
  version: "0.1.0"
---

# $NAME

<one-paragraph overview: what this skill does and the problem it captures>

## When to use

<conditions / non-conditions>

## Workflow

\`\`\`text
[1] …
[2] …
\`\`\`

## Common pitfalls

| Mistake | Fix |
| ------- | --- |
|         |     |

## Verification

- [ ]
EOF

# Insert README row alphabetically. Supports domain tables like
# "### Automation" and a fallback single table under "## Skills".
python3 - "$REPO/README.md" "$DOMAIN" "$NAME" "$PURPOSE" <<'PY'
import pathlib, re, sys
readme = pathlib.Path(sys.argv[1])
domain, name, purpose = sys.argv[2], sys.argv[3], sys.argv[4]
text = readme.read_text()
lines = text.splitlines(keepends=True)

heading = domain.capitalize()
row = f"| [`{name}`](skills/{domain}/{name}/SKILL.md) | {purpose} |"

def find_table(label):
    heading_index = None
    for i, line in enumerate(lines):
        if line.rstrip("\n") == label:
            heading_index = i
            break
    if heading_index is None:
        return None

    separator_index = None
    for i in range(heading_index + 1, len(lines)):
        stripped = lines[i].strip()
        if i != heading_index + 1 and stripped.startswith("#"):
            return None
        if stripped == "| ----- | ------- |":
            separator_index = i
            break
    if separator_index is None:
        return None

    start = separator_index + 1
    end = start
    while end < len(lines) and lines[end].startswith("| "):
        end += 1
    return start, end

label = f"### {heading}"
table = find_table(label)
if table is None:
    label = "## Skills"
    table = find_table(label)
if table is None:
    sys.exit(f"error: skill table not found in README.md")

start, end = table
rows = lines[start:end]
if not any(f"skills/{domain}/{name}/SKILL.md" in existing for existing in rows):
    rows.append(row + "\n")
rows.sort(
    key=lambda l: (
        re.match(r"\| \[`([^`]+)`\]", l.strip()).group(1)
        if re.match(r"\| \[`([^`]+)`\]", l.strip())
        else ""
    )
)
lines[start:end] = rows
readme.write_text("".join(lines))
print(f"inserted README row under {label}")
PY

cd "$REPO"
ln -sf "../../skills/$DOMAIN/$NAME" ".agent/skills/$NAME"
ln -sf "../../skills/$DOMAIN/$NAME" ".claude/skills/$NAME"

git add "skills/$DOMAIN/$NAME" "README.md" ".agent/skills/$NAME" ".claude/skills/$NAME"

cat <<EOF

scaffolded: $TARGET
next steps:
  1. fill in $TARGET/SKILL.md
  2. extract long code (≥ 15 lines) to scripts/, long config to references/
  3. cd "$REPO" && git commit -m "feat: add $NAME skill" && git push
EOF
