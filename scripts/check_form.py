#!/usr/bin/env python3
"""Structural checks for the Lab form.

The 4D form JSON is only validated by the schema otherwise, which says nothing
about whether an object points at a method that exists, whether a data source is
actually assigned somewhere, or whether a control hangs outside the window.

Exit status 0 when every check passes.
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FORM = os.path.join(ROOT, "Project/Sources/Forms/Lab/form.4DForm")
FORM_DIR = os.path.dirname(FORM)
MODEL = os.path.join(ROOT, "Project/Sources/Classes/OutlineLab.4dm")

failures = []


def check(condition, message):
    if not condition:
        failures.append(message)


def json5_free(text):
    return text


form = json.loads(json5_free(open(FORM).read()))
width, height = form["width"], form["height"]
objects = form["pages"][1]["objects"]

# ---------------------------------------------------------------- geometry
for name, spec in objects.items():
    for key in ("top", "left", "width", "height"):
        check(key in spec, "%s: missing %s" % (name, key))
    top = spec.get("top", 0)
    left = spec.get("left", 0)
    w = spec.get("width", 0)
    h = spec.get("height", 0)
    check(top >= 0 and left >= 0, "%s: negative origin" % name)
    check(left + w <= width, "%s: overflows form width (%d > %d)" % (name, left + w, width))
    check(top + h <= height, "%s: overflows form height (%d > %d)" % (name, top + h, height))
    check(w > 0 and h > 0, "%s: empty rectangle" % name)

# pairwise overlap of sibling controls (rectangles only; labels are allowed to
# sit close, so only report overlaps larger than a couple of pixels)
names = sorted(objects)
for i, a in enumerate(names):
    sa = objects[a]
    if sa["type"] in ("line", "rectangle"):
        continue
    for b in names[i + 1:]:
        sb = objects[b]
        if sb["type"] in ("line", "rectangle"):
            continue
        dx = min(sa["left"] + sa["width"], sb["left"] + sb["width"]) - max(sa["left"], sb["left"])
        dy = min(sa["top"] + sa["height"], sb["top"] + sb["height"]) - max(sa["top"], sb["top"])
        if dx > 2 and dy > 2:
            failures.append("%s and %s overlap by %dx%d px" % (a, b, dx, dy))

# ----------------------------------------------------------------- methods
referenced = set()
for name, spec in objects.items():
    target = spec.get("method")
    if not target:
        continue
    referenced.add(target)
    path = os.path.join(FORM_DIR, target)
    check(os.path.exists(path), "%s: method file %s missing" % (name, target))
    text = open(path).read()
    code = [line for line in text.splitlines()
            if line.strip() and not line.strip().startswith("//")]
    check(bool(code), "%s: object method is empty" % name)
    check(any(("Demo_" in line) or ("Form.lab." in line) for line in code),
          "%s: object method never reaches the model or a project method" % name)
    if spec["type"] == "checkbox":
        check(spec.get("events") == ["onClick"], "%s: checkbox wiring" % name)
    if spec["type"] in ("button", "pictureButton"):
        check(spec.get("events") == ["onClick"], "%s: button needs onClick" % name)

unused = [p for p in os.listdir(os.path.join(FORM_DIR, "ObjectMethods"))
          if "ObjectMethods/" + p not in referenced]
check(not unused, "object methods without an object: %s" % ", ".join(sorted(unused)))

# -------------------------------------------------------------- data sources
model_source = open(MODEL).read()
model_properties = set(re.findall(r"^property (\w+)", model_source, re.M))
assignments = set()
for base, _, files in os.walk(os.path.join(ROOT, "Project/Sources")):
    for name in files:
        if not name.endswith(".4dm"):
            continue
        text = open(os.path.join(base, name)).read()
        assignments |= set(re.findall(r"Form\.(\w+)\s*:=", text))

for name, spec in objects.items():
    source = spec.get("dataSource")
    if not source:
        continue
    check(source.startswith("Form."), "%s: dataSource %s is not Form.*" % (name, source))
    parts = source.split(".")
    if len(parts) == 3 and parts[1] == "lab":
        check(parts[2] in model_properties,
              "%s: Form.lab.%s is not a property of OutlineLab" % (name, parts[2]))
    elif len(parts) == 2:
        check(parts[1] in assignments,
              "%s: %s is never assigned by a project method" % (name, source))
    else:
        check(False, "%s: unsupported dataSource shape %s" % (name, source))

if failures:
    print("form check: FAILED")
    for line in failures:
        print("  -", line)
    sys.exit(1)

print("form check: ok (%d objects, %d attribute methods, %dx%d)"
      % (len(objects), len(referenced), width, height))
