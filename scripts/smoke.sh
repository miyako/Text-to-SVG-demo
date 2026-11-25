#!/usr/bin/env bash
# Headless acceptance for this demo: structural form checks, schema validation,
# a real 4D compilation and the component self test. No window, no GUI.
#
# Usage:
#   scripts/smoke.sh              # default tool4d path below
#   TOOL4D=/path/to/tool4d scripts/smoke.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
TOOL4D="${TOOL4D:-/Applications/tool4d/tool4d/21R4/100224/tool4d.app/Contents/MacOS/tool4d}"
OUT="/tmp/tts-demo"  # the 4D methods write here; keep both sides in sync
mkdir -p "$OUT"

status=0
declare -a ROWS=()

row() { ROWS+=("$1|$2|$3"); if [ "$1" != "passed" ]; then status=1; fi; }

need() {
  if [ ! -e "$1" ]; then
    echo "missing: $1" >&2
    echo "hint: run scripts/install_component.sh for Components/, or check the tool4d path" >&2
    exit 2
  fi
}

need "$TOOL4D"
need "Components/Text-to-SVG.4dbase"

run4d() {
  "$TOOL4D" --project "$ROOT/Project/Text-to-SVG-demo.4DProject" \
    --startup-method "$1" --skip-onstartup --dataless 2>&1 |
    grep -v '^PackageManager ' || true
}

# ---------------------------------------------------------------- structural
if python3 scripts/check_form.py > "$OUT/check-form.log" 2>&1; then
  row passed "form structure" "$(tail -1 "$OUT/check-form.log")"
else
  row failed "form structure" "$(tail -3 "$OUT/check-form.log" | tr '\n' ' ')"
fi

if [ -x tools/4dform/boon ] &&
   tools/4dform/boon .agents/schemas/4dform/formsSchema.json \
     Project/Sources/Forms/Lab/form.4DForm > "$OUT/schema.log" 2>&1; then
  row passed "form schema" "$(tail -1 "$OUT/schema.log")"
else
  row failed "form schema" "$(tail -3 "$OUT/schema.log" 2>/dev/null | tr '\n' ' ')"
fi

# ------------------------------------------------------------------ compile
rm -f "$OUT/compile.json"
if run4d Demo_Compile > "$OUT/compile.log" 2>&1; then
  if python3 - "$OUT/compile.json" <<'PY'
import json, sys
try:
    result = json.load(open(sys.argv[1]))["result"]
except Exception as exc:
    sys.exit("no compile report: %s" % exc)
errors = result.get("errors") or []
print("%s · %d error(s)" % ("compiled" if result["success"] else "failed", len(errors)))
sys.exit(0 if result["success"] else 1)
PY
  then
    row passed "4D compilation" "$(python3 -c "import json;d=json.load(open('$OUT/compile.json'))['result'];print('success', d['success'], '· targets', ', '.join(d.get('targets') or ['native']))")"
  else
    row failed "4D compilation" "see $OUT/compile.json"
  fi
else
  row failed "4D compilation" "tool4d exited nonzero, see $OUT/compile.log"
fi

# ---------------------------------------------------------------- self test
rm -f "$OUT/selftest.json"
if run4d Demo_RunSelfTest > "$OUT/selftest.log" 2>&1; then
  if python3 - "$OUT/selftest.json" <<'PY'
import json, sys
try:
    report = json.load(open(sys.argv[1]))
except Exception as exc:
    sys.exit("no self test report: %s" % exc)
failed = [c for c in report["checks"] if not c["passed"]]
for check in failed:
    print("FAIL %s | %s" % (check["check"], check["detail"]))
print("%d/%d checks passed" % (report["total"] - report["failed"], report["total"]))
sys.exit(0 if report["failed"] == 0 else 1)
PY
  then
    row passed "component self test" "$(python3 -c "import json;d=json.load(open('$OUT/selftest.json'));print(str(d['total'])+' checks, component '+str(d['version'])+' '+str(d['target']))")"
  else
    row failed "component self test" "see $OUT/selftest.json"
  fi
else
  row failed "component self test" "tool4d exited nonzero, see $OUT/selftest.log"
fi

# ------------------------------------------------------- example artifacts
rm -f "$OUT/examples/index.json"
if run4d Demo_Examples > "$OUT/examples.log" 2>&1 &&
   python3 - "$OUT/examples/index.json" <<'PY'
import json, sys
report = json.load(open(sys.argv[1]))
cases = report["cases"]
bad = [c["name"] for c in cases if not c["ok"] or not c["glyphCount"]]
for name in bad:
    print("FAIL %s" % name)
print("%d/%d cases shaped, component %s" % (len(cases) - len(bad), len(cases), report["component"]))
sys.exit(0 if len(cases) == 4 and not bad else 1)
PY
then
  row passed "example artifacts" "4 SVGs regenerated from the component"
else
  row failed "example artifacts" "see $OUT/examples.log"
fi

# ------------------------------------------------------- static form preview
if [ -x tools/4dform/fourdform ] &&
   tools/4dform/fourdform --output Docs/assets/form-static.png --scale 1 \
     Project/Sources/Forms/Lab/form.4DForm > "$OUT/preview.log" 2>&1; then
  row passed "static form preview" "Docs/assets/form-static.png"
else
  row failed "static form preview" "see $OUT/preview.log"
fi

# -------------------------------------------------------------------------- report
echo
printf '%-24s %-8s %s\n' "CHECK" "RESULT" "DETAIL"
printf '%-24s %-8s %s\n' "------------------------" "--------" "------"
for entry in "${ROWS[@]}"; do
  IFS='|' read -r result name detail <<< "$entry"
  printf '%-24s %-8s %s\n' "$name" "$result" "${detail:0:100}"
done

echo
if [ "$status" -eq 0 ]; then
  echo "smoke: ok — headless only. The window itself (DIALOG, picture rendering,"
  echo "zoom clicks) is still unverified here: tool4d has no GUI. Open the project"
  echo "in 4D and run Demo_Start for that."
else
  echo "smoke: FAILED" >&2
fi
exit "$status"
