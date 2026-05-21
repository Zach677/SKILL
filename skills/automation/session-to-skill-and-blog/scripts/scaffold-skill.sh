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

# Insert README row alphabetically. Supports both SKILL's domain tables and
# Zach-Skills' single skill table under "## Skills".
python3 - "$REPO/README.md" "$DOMAIN" "$NAME" "$PURPOSE" <<'PY'
import pathlib, re, sys
readme = pathlib.Path(sys.argv[1])
domain, name, purpose = sys.argv[2], sys.argv[3], sys.argv[4]
text = readme.read_text()

heading = domain.capitalize()
row = f"| [`{name}`](skills/{domain}/{name}/SKILL.md) | {purpose} |"

domain_pat = re.compile(
    rf"(### {re.escape(heading)}\n.*?\| ----- \| ------- \|\n)((?:\|.*\n)+)",
    re.S,
)
flat_pat = re.compile(
    r"(## Skills\n.*?\| ----- \| ------- \|\n)((?:\|.*\n)+)",
    re.S,
)

m = domain_pat.search(text)
label = f"### {heading}"
if not m:
    m = flat_pat.search(text)
    label = "## Skills"
if not m:
    sys.exit(f"error: skill table not found in README.md")

rows = m.group(2).splitlines(keepends=True)
rows.append(row + "\n")
rows.sort(key=lambda l: (re.match(r"\| \[`([^`]+)`\]", l.strip()) or re.match(r"", "")).group(1)
                       if re.match(r"\| \[`([^`]+)`\]", l.strip()) else "")
new = m.group(1) + "".join(rows)
readme.write_text(text[:m.start()] + new + text[m.end():])
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
