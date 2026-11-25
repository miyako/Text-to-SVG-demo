#!/usr/bin/env bash
# Fetch the pinned Text-to-SVG release into Components/ so the project can run.
#
# Components/ is gitignored on purpose: the demo ships no binary of someone
# else's component. Run this once after cloning, then open the project in 4D,
# or run scripts/smoke.sh which needs the component too.
#
# Usage: scripts/install_component.sh [--force]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPS="$ROOT/Project/Sources/dependencies.json"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

command -v gh >/dev/null || { echo "gh (GitHub CLI) is required" >&2; exit 1; }

read -r REPO VERSION < <(python3 - "$DEPS" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))["dependencies"]["Text-to-SVG"]
print(d["github"], d["version"])
PY
)
echo "component: $REPO @ $VERSION"

DEST="$ROOT/Components"
case "$DEST" in
  "$ROOT"/*) ;;
  *) echo "refusing to write outside the repository: $DEST" >&2; exit 1 ;;
esac
if [ -d "$DEST/Text-to-SVG.4dbase" ] && [ "${1:-}" != "--force" ]; then
  echo "already installed: $DEST/Text-to-SVG.4dbase (use --force to replace)"
  exit 0
fi

# Download the published asset without trusting the working tree.
gh release download "$VERSION" --repo "$REPO" --pattern Text-to-SVG.zip --dir "$WORK" \
  || { echo "release $VERSION has no Text-to-SVG.zip" >&2; exit 1; }

python3 - "$WORK/Text-to-SVG.zip" <<'PY'
import sys, zipfile
path = sys.argv[1]
with zipfile.ZipFile(path) as z:
    names = z.namelist()
    bad = [n for n in names if n.startswith("/") or ".." in n.split("/")]
    if bad:
        sys.exit("unsafe paths in archive: %s" % bad[:3])
    if not any(n.startswith("Text-to-SVG.4dbase/") for n in names):
        sys.exit("archive does not contain Text-to-SVG.4dbase/")
    if not any(n.endswith("Text-to-SVG.4DZ") for n in names):
        sys.exit("archive has no compiled Text-to-SVG.4DZ")
print("archive ok: %d entries" % len(names))
PY

rm -rf "$DEST/Text-to-SVG.4dbase"
mkdir -p "$DEST"
unzip -q "$WORK/Text-to-SVG.zip" -d "$DEST"

# The bundle is compiled-only: no class source, so the demo gets its API through
# Resources/en.lproj/syntax*.json. The CLI inside must stay executable.
BIN="$DEST/Text-to-SVG.4dbase/Resources/bin"
if [ -d "$BIN" ]; then
  find "$BIN" -type f -name 'text-to-svg' -exec chmod +x {} +
fi

echo "installed: $DEST/Text-to-SVG.4dbase"
ls "$DEST/Text-to-SVG.4dbase"
