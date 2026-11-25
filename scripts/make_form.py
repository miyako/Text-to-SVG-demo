#!/usr/bin/env python3
"""Generate Project/Sources/Forms/Lab/form.4DForm with deterministic geometry."""
import json
import os

W, H = 1180, 840
MONO = "Courier New"
SANS = "Arial"
INK = "#101828"
MUTED = "#5b6478"
FAINT = "#8a94a6"
ACCENT = "#0f766e"

objects = {}


def add(name, spec):
    assert name not in objects, name
    objects[name] = spec


def text(name, left, top, width, height, string, size=12, bold=False,
         color=MUTED, align=None):
    spec = {
        "type": "text",
        "left": left, "top": top, "width": width, "height": height,
        "text": string,
        "fontFamily": SANS, "fontSize": size, "stroke": color,
    }
    if bold:
        spec["fontWeight"] = "bold"
    if align:
        spec["textAlign"] = align
    add(name, spec)


def readonly(name, left, top, width, height, dataSource, size=11,
             font=MONO, color=MUTED, multiline="no", align=None):
    spec = {
        "type": "input",
        "left": left, "top": top, "width": width, "height": height,
        "dataSource": dataSource,
        "dataSourceTypeHint": "text",
        "enterable": False,
        "focusable": False,
        "borderStyle": "none",
        "fontFamily": font, "fontSize": size, "stroke": color,
        "multiline": multiline,
    }
    if multiline == "yes":
        spec["wordwrap"] = "normal"
        spec["scrollbarVertical"] = "automatic"
    if align:
        spec["textAlign"] = align
    add(name, spec)


def entry(name, left, top, width, height, dataSource, hint="text", size=13,
          method=None, events=None, align=None, font=SANS):
    spec = {
        "type": "input",
        "left": left, "top": top, "width": width, "height": height,
        "dataSource": dataSource,
        "dataSourceTypeHint": hint,
        "fontFamily": font, "fontSize": size,
    }
    if method:
        spec["method"] = "ObjectMethods/" + method
        spec["events"] = events or ["onDataChange"]
    if align:
        spec["textAlign"] = align
    add(name, spec)


def button(name, left, top, width, height, label, method, size=12):
    add(name, {
        "type": "button",
        "left": left, "top": top, "width": width, "height": height,
        "text": label,
        "fontFamily": SANS, "fontSize": size,
        "method": "ObjectMethods/" + method,
        "events": ["onClick"],
    })


# ------------------------------------------------------------------ header
text("title", 28, 16, 540, 40, "Text-to-SVG", 27, True, INK)
text("subtitle", 28, 58, 660, 20,
     "glyph outlines → SVG from a 4D component · every number in physical units",
     13, False, MUTED)
readonly("versionText", 700, 22, 452, 18, "Form.versionText", 12, SANS,
         FAINT, align="right")
readonly("statusText", 700, 42, 452, 18, "Form.statusText", 12, SANS,
         ACCENT, align="right")

# ------------------------------------------------------------- font section
text("labelFont", 28, 94, 240, 14, "FONT FILE", 11, True, FAINT)
add("fontDrop", {
    "type": "dropdown",
    "left": 28, "top": 110, "width": 356, "height": 22,
    "dataSource": "Form.fontDrop",
    "dataSourceTypeHint": "object",
    "fontFamily": SANS, "fontSize": 12,
    "method": "ObjectMethods/fontDrop.4dm",
    "events": ["onDataChange"],
})

readonly("fontPathText", 28, 138, 356, 18, "Form.fontPathText", 11, MONO, FAINT)

text("labelFace", 28, 164, 96, 18, "Face index", 12, False, MUTED)
entry("faceInput", 126, 162, 54, 22, "Form.lab.faceIndex", "integer", 12,
      "faceInput.4dm", ["onDataChange"], align="right")
add("faceStep", {
    "type": "stepper",
    "left": 184, "top": 160, "width": 14, "height": 26,
    "dataSource": "Form.lab.faceIndex",
    "method": "ObjectMethods/faceStep.4dm",
    "events": ["onDataChange"],
})
readonly("faceHint", 204, 164, 180, 18, "Form.faceHint", 11, SANS, FAINT)

text("labelText", 28, 196, 60, 18, "Text", 12, False, MUTED)
entry("textInput", 28, 214, 356, 30, "Form.lab.text", "text", 16,
      method="textInput.4dm", events=["onDataChange"])

text("labelSize", 28, 256, 60, 18, "Size", 12, False, MUTED)
entry("sizeInput", 88, 254, 64, 24, "Form.lab.fontSize", "number", 12,
      "sizeInput.4dm", ["onDataChange"], align="right")
add("unitsDrop", {
    "type": "dropdown",
    "left": 160, "top": 254, "width": 80, "height": 22,
    "dataSource": "Form.lab.units",
    "dataSourceTypeHint": "text",
    "choiceList": ["mm", "pt", "px", "in"],
    "saveAs": "value",
    "fontFamily": SANS, "fontSize": 12,
    "method": "ObjectMethods/unitsDrop.4dm",
    "events": ["onDataChange"],
})
readonly("sizeHint", 248, 258, 136, 18, "Form.sizeHint", 11, SANS, FAINT)

add("guidesCheck", {
    "type": "checkbox",
    "left": 28, "top": 288, "width": 260, "height": 18,
    "text": "Guides in the preview",
    "dataSource": "Form.lab.showGuides",
    "dataSourceTypeHint": "boolean",
    "fontFamily": SANS, "fontSize": 12,
    "method": "ObjectMethods/guidesCheck.4dm",
    "events": ["onClick"],
})

# ------------------------------------------------------------------ presets
text("labelPresets", 28, 320, 300, 14, "PRESETS — ONE CLICK EACH", 11, True, FAINT)
PRESETS = [
    "Latin · AV Office",
    "Ligature · office",
    "Ligature · ﬁle",
    "CJK · 日本語",
    "RTL · مرحبا",
    "Emoji font",
    "Missing glyph",
    "Empty text",
    "Bad font path",
]
for index, label in enumerate(PRESETS):
    column = index % 2
    row = index // 2
    button("preset%d" % (index + 1), 28 + column * 184, 338 + row * 32,
           172, 26, label, "preset%d.4dm" % (index + 1), 12)
button("compareBtn", 28 + 184, 338 + 4 * 32, 172, 26, "Compare units",
       "compareBtn.4dm", 12)

# ------------------------------------------------------------------ actions
button("convertBtn", 28, 512, 110, 26, "Convert", "convertBtn.4dm", 12)
button("saveBtn", 148, 512, 110, 26, "Save SVG", "saveBtn.4dm", 12)
button("copyBtn", 268, 512, 116, 26, "Copy SVG", "copyBtn.4dm", 12)

text("labelZoom", 28, 548, 52, 18, "ZOOM", 11, True, FAINT)
for index, factor in enumerate(("1", "2", "4", "8")):
    button("zoom%s" % factor, 84 + index * 56, 546, 50, 24,
           factor + "×", "zoom%s.4dm" % factor, 12)
button("resetBtn", 308, 546, 76, 24, "Reset", "resetBtn.4dm", 12)

# ---------------------------------------------------------------------- log
text("labelLog", 28, 578, 300, 14, "RECENT CALLS", 11, True, FAINT)
readonly("logText", 28, 596, 356, 104, "Form.logText", 11, MONO, MUTED,
         multiline="yes")
readonly("errorText", 28, 708, 356, 112, "Form.errorText", 11, MONO, "#b42318",
         multiline="yes")

# ------------------------------------------------------------------ preview
add("previewPanel", {
    "type": "rectangle",
    "left": 404, "top": 94, "width": 748, "height": 424,
    "fill": "#ffffff", "stroke": "#c9d1e0", "strokeWidth": 1,
})
add("preview", {
    "type": "input",
    "left": 412, "top": 102, "width": 732, "height": 408,
    "dataSource": "Form.lab.preview",
    "dataSourceTypeHint": "picture",
    "pictureFormat": "proportionalCenter",
    "borderStyle": "none",
    "focusable": False,
    "dragging": "none",
    "dropping": "none",
    "method": "ObjectMethods/preview.4dm",
    "events": ["onClick"],
})
readonly("legend", 404, 524, 748, 18, "Form.legend", 11, SANS, FAINT)
readonly("metricsText", 404, 546, 748, 152, "Form.metricsText", 12, MONO, INK,
         multiline="yes")
readonly("panelTitle", 404, 702, 748, 16, "Form.panelTitle", 11, SANS, FAINT)
readonly("svgText", 404, 720, 748, 100, "Form.svgText", 10, MONO, MUTED,
         multiline="yes")

form = {
    "$4d": {"version": "1", "kind": "form"},
    "windowTitle": "Text-to-SVG Lab",
    "destination": "detailScreen",
    "width": W,
    "height": H,
    "rightMargin": 20,
    "bottomMargin": 20,
    "windowSizingX": "fixed",
    "windowSizingY": "fixed",
    "windowMinWidth": W,
    "windowMinHeight": H,
    "windowMaxWidth": W,
    "windowMaxHeight": H,
    "events": ["onLoad", "onUnload"],
    "method": "method.4dm",
    "pages": [{"objects": {}}, {"objects": objects}],
}

target = os.path.join(os.path.dirname(__file__), os.pardir,
                      "Project/Sources/Forms/Lab/form.4DForm")
target = os.path.abspath(target)
os.makedirs(os.path.dirname(target), exist_ok=True)
with open(target, "w") as handle:
    json.dump(form, handle, indent="\t", ensure_ascii=False)
    handle.write("\n")
print("wrote", target, len(objects), "objects")
