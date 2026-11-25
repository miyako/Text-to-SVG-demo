# Agent guide for Text-to-SVG-demo

This repository is a **demo project**, not a component. It consumes the compiled
`Text-to-SVG` component and shows what it returns. The component itself lives at
[miyako/Text-to-SVG](https://github.com/miyako/Text-to-SVG) and its own
`AGENTS.md` governs that repository only — nothing there applies here.

## What to read first

* `README.md` — what the demo shows, the points of interest, and the evidence
  table that distinguishes verified from unverified behaviour.
* `Docs/FINDINGS.md` — the 4D and component traps already paid for. Read it
  before "fixing" anything that looks odd; several oddities are the platform.
* `.agents/skills/<name>/SKILL.md` — the skillset submodule (`miyako/skills`,
  branch `dist`). `4dform` documents the form JSON, `4dcli` documents `tool4d`,
  `4dlang` answers 4D syntax questions, `4dlsp` runs the analyzer.

## Hard invariants

1. **No component binary in git.** `Components/` is ignored; the pinned version
   lives in `Project/Sources/dependencies.json` and `scripts/install_component.sh`
   fetches exactly that release. Never commit or patch `Components/`.
2. **The form JSON is generated.** `Project/Sources/Forms/Lab/form.4DForm` comes
   from `scripts/make_form.py`; edit the generator and re-run it, otherwise the
   next regeneration silently reverts your change. Validate with
   `tools/4dform/boon .agents/schemas/4dform/formsSchema.json <form>`.
3. **Object methods stay tiny.** Each `Project/Sources/Forms/Lab/ObjectMethods/*.4dm`
   is one call into a `Demo_*` project method or one model call. Logic belongs in
   `Demo_Refresh` / `Demo_Render` / `Demo_Sync` or in `cs.OutlineLab`.
4. **The model owns the state.** `cs.OutlineLab` holds every parameter and every
   derived value; the form only mirrors plain values (`Form.lab.text`,
   `Form.metricsText`, …). Never bind a control to the model object itself.
5. **Errors are shown, never swallowed.** Every `convert()` result becomes
   `errorCode` / `errorMessage` / `errorHint` and appears in the panel. An
   unexpected 4D error is caught with a handler installed `ek local` and removed
   immediately (`Demo_OnErr` is used only around a guarded call).
6. **No unverified claims.** If a check needs a GUI or Windows, say `not_run` and
   why. `tool4d` cannot open windows, rasterise SVG, or list form objects.

## Verify before you commit

```sh
scripts/smoke.sh
```

Five rows must be `passed`: form structure, form schema, 4D compilation, the
30-check component self test, static form preview. The script writes its evidence
to `/tmp/tts-demo/` (`selftest.json`, `compile.json`, `error.json` when a guarded
call raised something).

Faster inner loops:

```sh
python3 scripts/check_form.py                  # geometry + wiring, no 4D
TOOL4D=... tool4d --project Project/Text-to-SVG-demo.4DProject \
  --startup-method Demo_RunSelfTest --skip-onstartup --dataless
```

Add a self-test check whenever you discover a behaviour worth keeping: the
assertions in `Demo_SelfTest` caught three false claims of mine (`units` scaling,
ink below the baseline, `invalid_font` versus `invalid_argument`).

## Conventions in the 4D source

* `var` declarations go at the top of the method or function for readability; a
  `var` inside a block does compile and stay block-scoped, so do not rely on
  either habit accidentally.
* `Min` / `Max` are array commands — use the `minOf` / `maxOf` helpers. The
  compiler blames a bogus cast (`Impossible to cast Real to Array<Variant>`) and
  never names the command.
* `String(value)` is locale-formatted, and `String(value; "0.#####")` returns
  `<<<<<<<` for multi-digit values — `OutlineLab.num()` is the only sanctioned
  formatter for SVG attributes. There is no third "decimal separator" argument.
* `This.q()` / `Char(34)` is still how quotes are embedded in generated SVG; keep
  long concatenations on one line rather than relying on `\` continuations.
* `DOM Parse XML variable` needs a variable, never an object property path.
* Folder constants are `fk home folder`, `fk posix path`, … — the unprefixed names
  no longer exist and fail only at runtime.
* The component is compiled-only, so analyzer "unknown class" messages for
  `cs.TextToSVG.*` are expected; the real compiler accepts them.

## Scope discipline

Do not add features that the component does not support (no colour, no wrapping,
no RTL). Do not "fix" the demo by editing the generated SVGs in `Docs/examples/`
— regenerate them with `Demo_Examples`. If you change the visual design, rerender
`Docs/assets/form-static.png` through `scripts/smoke.sh` so the README figure and
the form cannot drift apart.
