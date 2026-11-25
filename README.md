# Text-to-SVG demo

An interactive 4D project that turns text into SVG glyph outlines with
[miyako/Text-to-SVG](https://github.com/miyako/Text-to-SVG) `0.1.2` — a 4D
component that wraps a bundled native shaper and answers in physical units.

The demo is deliberately a **lab**, not a screenshot: every number the component
returns is on screen, next to the SVG it produced, next to the error it refused
to hide.

![AV Office in 10 mm, annotated by the demo](Docs/examples/latin.svg)

## What the form does

Left column — what you ask for:

| Control | Effect |
| --- | --- |
| Font dropdown | 369 faces scanned from the host (`.ttf`, `.otf`, `.ttc`), name-sorted |
| Face stepper | `faceIndex` inside a collection such as a 9-face `.ttc` |
| Text field | the string to shape; editing it re-converts on <kbd>Return</kbd> |
| Size + unit | `fontSize` and one of `mm` / `pt` / `px` / `in` |
| Guides checkbox | rebuild the annotated SVG only, without calling the component |
| 9 presets | one per interesting case, including four deliberate failures |
| Convert / Save / Copy | re-convert, write both SVGs to disk, copy the SVG to the clipboard |
| Zoom 1× 2× 4× 8× | rescale the annotated SVG so hairlines stay visible |

Right column — what the component answered:

* the annotated preview (grey dashed em box, red baseline, blue dashed advance,
  green ink box) drawn over the outlines themselves,
* `advance`, `inkBounds`, `glyphCount`, exit code and elapsed milliseconds,
* the **raw** `value.svg` string, byte for byte, because that is what a host
  application would consume.

Failures are first-class: pick a preset that is known to fail and the panel shows
the error code, the component's message and a hint — the picture simply stays
empty instead of showing a stale drawing.

## Points of interest

1. **The dependency is compiled-only.** `Text-to-SVG.4dbase` ships a `.4DZ` and a
   native binary but no class source, so the whole API is discovered through
   `Resources/en.lproj/syntaxEN.json`. `Project/Sources/dependencies.json` pins the
   version; a real 4D IDE fetches it, and `scripts/install_component.sh` does the
   same from the release ZIP for headless runs.
2. **One call, one envelope.** `cs.TextToSVG.TextOutline.new(target)` +
   `.convert({fontFile; text; fontSize; units; faceIndex})` returns
   `{ok; success; exitCode; value:{protocol; svg; pathData; inkBounds; advance; …}}`
   or `{error:{code; message}}`. The demo prints the raw envelope so the contract
   is visible, not paraphrased.
3. **`units` is a label, not a scale — verified.** Converting 10 mm and 10 pt
   returns *byte-identical* `pathData`; only the `width="…mm"` / `width="…pt"`
   suffix of the `<svg>` changes. So "10 pt" and "10 mm" are the same drawing at
   different implied physical sizes. The demo's unit table says so, because the
   first version of this demo claimed otherwise and the self test caught it.
4. **The SVG canvas is the ink box, not the advance.** For `AV Office` at 10 mm
   the SVG is 40.913 mm wide while `advance` is 41.313 mm: the trailing side
   bearing is outside the canvas. Place glyphs by `advance`, crop by `inkBounds`.
5. **Character count ≠ glyph count.** `office` with HelveticaNeue is 6 characters
   and 4 glyphs — the `ffi` ligature is real; `ﬁle` (U+FB01) is 4 characters and
   3 glyphs. With `faceIndex` you can also prove that face 0 and face 7 of the
   same `.ttc` differ in `pathData`.
6. **Errors are specific.** `unsupported_layout` (Arabic refused before shaping),
   `missing_glyph` (Arial cannot render 日本語), `limit_exceeded` (Apple Color Emoji
   is a 192 MiB collection; the cap is 64 MiB), `invalid_argument` (a relative
   font path), `invalid_request` (fontSize 0 or 20000). Each preset shows one.
7. **It is fast enough to be interactive.** A Latin conversion costs ~11 ms and a
   CJK one ~21 ms on this host, including the process hand-off — which is why the
   form can re-convert on every keystroke-commit and why zooming rebuilds only
   the annotated SVG, never the component call.
8. **Everything the demo writes is reproducible.** `scripts/smoke.sh` compiles the
   project with `tool4d`, runs the 30-check self test and regenerates
   `Docs/examples/*.svg`.

## Setup

```sh
git clone --recurse-submodules https://github.com/miyako/Text-to-SVG-demo
cd Text-to-SVG-demo
scripts/install_component.sh        # Components/Text-to-SVG.4dbase from the 0.1.2 release
```

Then either open `Project/Text-to-SVG-demo.4DProject` in 4D 21 R5 (or 20.7 LTS)
and run `Demo_Start`, or stay headless:

```sh
scripts/smoke.sh
```

`smoke.sh` needs `tool4d` (`TOOL4D=/path/to/tool4d` to override the default) and
prints one row per check:

```
CHECK                    RESULT   DETAIL
------------------------ -------- ------
form structure           passed   form check: ok (47 objects, 26 attribute methods, 1180x840)
form schema              passed   instance Project/Sources/Forms/Lab/form.4DForm: ok
4D compilation           passed   success True · targets native
component self test      passed   30 checks, component 0.1.2 macOS-universal
example artifacts        passed   4 SVGs regenerated from the component
static form preview      passed   Docs/assets/form-static.png
```

## Evidence — what is actually verified

Verified on macOS 27.2.1 (Apple Silicon, `arm64`), 4D `tool4d` 21 R4 build 100224,
component `0.1.2` / `macOS-universal`):

| Check | Status | How |
| --- | --- | --- |
| 30-check component self test | **passed** | `Demo_RunSelfTest` → `/tmp/tts-demo/selftest.json` |
| Full project compilation | **passed** | `Compile project`, `Demo_Compile` → `/tmp/tts-demo/compile.json` |
| Form schema + wiring | **passed** | `tools/4dform/boon`, `scripts/check_form.py` |
| The form definition loads | **passed** | `FORM LOAD("Lab")` under a local error handler |
| Annotated SVG is well-formed | **passed** | `DOM Parse XML variable` inside the demo, re-checked with Python |
| Example SVGs (`Docs/examples/`) | **passed** | `Demo_Examples`, asserted by `smoke.sh`; byte-identical to the committed files |
| The window itself (dialog, picture rendering, mouse) | **not_run** | `tool4d` has no GUI; open the project in 4D and run `Demo_Start` |
| `SVG EXPORT TO PICTURE` preview | **not_run** | the command is unavailable under `tool4d`, so `Form.lab.preview` stays empty there |
| Windows 4D, Intel 4D | **not_run** | not available on this host — `FontScanner` has a Windows branch that was never executed |

Nothing here claims Windows or GUI acceptance. The annotated SVG is valid XML
and the exact component payload, but it was never rasterised by 4D on this host.

## Repository layout

```
Project/Text-to-SVG-demo.4DProject   4D 21 R5 project, compatibilityVersion 2060
Project/Sources/Classes/            FontScanner (host font discovery), OutlineLab (the model)
Project/Sources/Forms/Lab/          form.4DForm + 26 object methods (one call each)
Project/Sources/Methods/            Demo_* entry points, self test, compile helper
scripts/make_form.py                regenerates the form JSON deterministically
scripts/check_form.py               geometry, method wiring and data-source checks
scripts/install_component.sh        release ZIP → Components/ (pinned version)
scripts/smoke.sh                    compile + self test + preview, headless
Docs/examples/                      component output, committed as SVG so GitHub renders it
Docs/FINDINGS.md                    the 4D/component chokepoints met while building this
```

## Chokepoints

`Docs/FINDINGS.md` lists every trap that cost real time here — the 4D constants
that only fail at runtime, `DOM Parse XML variable` refusing an object property,
`String(value; "0.#####")` printing `<<<<<<<`, `units` not scaling, and what
`tool4d` can and cannot verify. It is the part of this repository worth reading
if you plan to wrap this component yourself.

## License

Demo code is MIT. The component is a separate project with its own license;
`Components/` is not committed and is installed from its signed release.
