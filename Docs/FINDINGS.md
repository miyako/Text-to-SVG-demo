# Chokepoints, failures and findings

Everything below was hit while building this demo against
`miyako/Text-to-SVG` `0.1.2` (compiled-only) from 4D `tool4d` 21 R4 build 100224
on macOS 27.2.1 / `arm64`. Each entry states what broke, why it is not obvious,
and what to do instead. "Verified" means the behaviour was reproduced here, not
that it is documented by 4D.

## 1. The component has no class source, so tooling sees an unknown class

`Components/Text-to-SVG.4dbase` contains `Documentation`, `Libraries`,
`Resources` and `Text-to-SVG.4DZ`. There is no `.4dm` for
`cs.TextToSVG.TextOutline`.

* Consequences: the analyzer (`tool4d-lsp-stdio validate`) reports
  `The class cs.TextToSVG is unknown` and `version/convert does not exist on type
  cs.TextToSVG.TextOutline` for perfectly correct code.
* The **real compiler** accepts it (`Compile project` → `success: true`), and the
  API surface is discoverable only through `Resources/en.lproj/syntaxEN.json`.
* Practical rule: treat analyzer "unknown class" diagnostics as unproven for any
  compiled-only dependency, and always pair analysis with an actual compile.

Verified.

## 2. Constants are not validated at compile time

These compile cleanly and then fail at runtime:

| Written | `Compile project` | When the method runs |
| --- | --- | --- |
| `Folder(Home folder)` | `success: true`, no errors | `tool4d.FiFo [2] The constant value is invalid` |
| `Folder(Desktop folder)` | same | same |
| `Folder(Windows folder)` | same | same |

The 21 R4/R5 constant set is the `fk`-prefixed one:
`fk home folder`, `fk desktop folder`, `fk system folder`, `fk posix path`,
`fk platform path`, `fk database folder`, … (confirmed by grepping
`4D_ConstantsEN.xlf` inside the tool4d bundle). The old unprefixed names are gone.

Two things make this expensive: **the compiler accepts the stale name**, so a
green compile is not evidence, and the failure names no constant, only
`The constant value is invalid`. If a method dies that way under
`--startup-method`, check the constants before blaming your path handling.

Verified: compiled clean with the bad constant present, then failed at execution.

## 3. `DOM Parse XML variable` refuses an object property

```4d
$dom:=DOM Parse XML variable(This.annotatedSvg)   // error 59
$svg:=This.annotatedSvg
$dom:=DOM Parse XML variable($svg)                // works
```

The command needs a real variable; a property path raises
`tool4d.4DRT [59] 4D was expecting a field or a variable or a parameter or an
object`, and outside a `Try` block that aborts the calling method. Inside `Try`
it is catchable but `ON ERR CALL` is *not* invoked, so a handler-based log looks
empty while the preview stays blank — which is exactly how this looked the first
time round.

Verified. Fix: copy to a local variable first (`OutlineLab.renderPreview`).

## 4. `String(value; "0.#####")` prints `<<<<<<<`

Observed on this host, same process:

| Expression | Result |
| --- | --- |
| `String(41.3134765625; "0.#####")` | `<<<<<<<` |
| `String(5618.49; "0.#####")` | `<<<<` |
| `String(0.4; "0.#####")` | `0.4` |
| `String(41.3134765625; "##.#####")` | `41.31347` |
| `String(41.3134765625)` | `41.3134765625` |

So any value with two or more integer digits fails the `0.#####` pattern, which
makes it useless for geometry: SVG attributes were full of `<`.

Second trap in the same area: `String(value)` formats with the **host locale**
decimal separator. Writing that into an SVG attribute would corrupt every
coordinate on a comma-decimal system.

What the demo does instead (`OutlineLab.num`): take `String(value)`, replace the
locale separator with `.`, trim trailing zeros. Exact component values, portable
output.

Also note: `String(value; format; separator)` is not an overload — the third
argument is a *thousands/format* separator and 4D raises
`4D was expecting a text expression` for `"."`.

Verified.

## 5. `units` does not scale anything

Requesting `fontSize: 10` with `units: "mm"` and `units: "pt"` returns identical
`pathData`, identical `inkBounds` (40.913 × 7.407), identical `advance`
(41.313). Only the suffix changes:

```
width="40.9130859375mm"  →  width="40.9130859375pt"
```

`OutlineLab.compareUnits` now states this in the UI instead of pretending to be a
unit converter. If you need real conversion the demo computes millimetres itself
via `mmPerUnit()` (25.4/72 for pt, 25.4/96 for px).

Verified — and the first version of the self test asserted the opposite
("the same numerals in pt are physically smaller"), which is exactly why the
assertion exists.

## 6. The SVG canvas is the ink box, so `advance` can be clipped

`AV Office` at 10 mm: SVG `width` is 40.913 mm, `advance` is 41.313 mm, and the
`viewBox` starts at `-0.0146484375` (the ink's left overhang). The trailing side
bearing simply is not in the canvas. Lay out runs by `advance`; crop by
`inkBounds`.

Related: ink can dip *below* the baseline. `inkBounds.y = -7.285`,
`height = 7.407` → the bottom edge is at `+0.122 mm` (round-letter overshoot). An
assertion demanding "ink never goes below the baseline" fails on correct output.

Verified.

## 7. Error codes: there are six, and one is easy to miss

`unsupported_layout`, `missing_glyph`, `limit_exceeded`, `invalid_font`,
`invalid_request` are in the component docs. The demo also received
**`invalid_argument`**, which is what a *relative* `fontFile` produces:

```
invalid_argument: fontFile must be an absolute or host filesystem path
```

and for an empty path:

```
invalid_argument: fontFile must be nonempty Text without NUL
```

`Docs`-level code lists that omit `invalid_argument` will mislead a host
application. The demo's `hintFor()` maps it.

Verified.

## 8. `4D.File.extension` includes the dot

`Lowcase extension = ".ttc"` — not `"ttc"`. A `FontScanner` that compares against
`"ttf"/"otf"/"ttc"` silently finds **zero** fonts on a host with 369 of them, and
because `folder.files()` works fine the bug looks like a permissions problem.

Verified (the first font scan returned 0 faces).

## 9. `4D.Folder.delete()` refuses a non-empty folder

`$folder.delete()` → `tool4d.xbox [651] Folder  not empty` (note the doubled space
in the message). For a scratch directory rebuilt on every run, use the classic
command:

```4d
DELETE FOLDER($folder.path; Delete with contents)
```

Fine print that cost time: the error is catchable, but it is **not** an
`ON ERR CALL` event, and `Last errors[1]` inside the `Catch` block was itself
empty (`-10713 Index in collection is out of range`), so a "log the caught error"
handler hides both the original failure and its own. Write a fixed sentinel
string from `Catch` instead.

Verified.

## 10. `Open document` is a function, not a procedure

`Open document($path)` alone fails compilation with
`This function has been called as a procedure`. Assign or discard the result:

```4d
$opened:=String(Open document($file.platformPath))
```

Verified (compile error until fixed).

## 11. `Min` / `Max` are array commands, and the compiler will not say so

`$r:=Min(1; 2)` fails `Compile project` with two diagnostics that never mention
`Min`:

```
Impossible to cast Real to Array<Variant>.
Invalid constant type : Real
```

The demo carries `minOf` / `maxOf` helpers. Related: `var` inside an `If` or
`For each` block **is** legal in this build (block-scoped) — that claim, which is
in several 4D guides, did not reproduce here.

Verified.

## 12. `String(value; format; separator)` is not an overload

`String(41.3; "0.#####"; ".")` fails compilation with
`At least one parameter type does not match the prototype(s) of the function
"String"` plus `Invalid constant type : Alphanumeric`. The third argument of
`String` is not a decimal separator, so locale-independent formatting has to be
done by hand (`OutlineLab.num`).

Verified.

## 13. What `tool4d` cannot do here, and how far the evidence reaches

| Capability | Under `tool4d` | Consequence |
| --- | --- | --- |
| `SVG EXPORT TO PICTURE` | unavailable | `Form.lab.preview` stays `Null`; the annotated SVG is written to disk instead |
| form windows (`DIALOG`, `Open form window`) | no GUI | the window, mouse handling and picture rendering are **not** verified here |
| `FORM GET OBJECTS($pointers; "Lab"; "")` | error 59, `4D was expecting a variable or a parameter or a variable or a parameter or a numeric expression` | object-level introspection is impossible headlessly |
| `FORM Convert to dynamic("Lab")` | error 59, `4D was expecting a text expression` | a form *name* is not an acceptable argument in this build |
| `FORM LOAD("Lab"; *)` | works, no window | the strongest available headless form gate; an unknown name raises error 81 `The form was not found`, so it is a real assertion, not a no-op |
| `Compile project` | available via a startup method | see `Demo_Compile`; exit code alone is not evidence, read the JSON |
| `--compile` CLI switch | does not exist | always compile from 4D code |
| environment variables (`Get environment variable`) | does not exist | `FontScanner` cannot read `%LOCALAPPDATA%`, so per-user Windows fonts are skipped (documented in the class) |

Verified by attempting each one.

## 14. Font discovery is the slowest part of startup, and it is host-specific

369 faces on this macOS host, scanned in well under a second, sorted by name. The
Windows branch only visits `<system>/../Fonts` (i.e. `C:\Windows\Fonts`) because of
the environment-variable limitation above. That branch has **never been executed
here** — see the evidence table in the README.

## 15. Form JSON: what the schema does not tell you

* `pages[0]` may be empty, but the objects live in `pages[1].objects`; a form
  whose only page is empty loads and shows nothing.
* `top` / `left` are required on every object (labels included).
* An object with a `method` needs `events`; without `events` the method is never
  called and nothing reports it.
* The `method` value is relative to the form folder — `"ObjectMethods/x.4dm"`. A
  generator that also prefixes `ObjectMethods/` produces
  `ObjectMethods/ObjectMethods/x.4dm`, which the schema accepts and 4D silently
  ignores. `scripts/check_form.py` exists because of this class of bug: it checks
  geometry, that every method file exists and reaches the model, and that every
  `Form.lab.*` data source is a real property of the model class.
* A dropdown bound with `dataSource` + `dataSourceTypeHint` needs
  `{values; index; currentValue}`; the `index` is **zero-based** on the model side
  (`PreferIndex` returns 0 for the first font).

Verified.

## 16. The analyzer is not the compiler, in both directions

`tool4d-lsp-stdio validate` flagged real errors the compiler also flags
(`Open document`, `\"` continuations) and flagged non-errors on the compiled-only
component. Use it for syntax, always finish with `Compile project`.

Verified.
