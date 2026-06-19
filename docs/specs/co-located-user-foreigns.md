# Spec: co-located user foreigns (harmonize purejl + psgo to purs)

**Goal.** Make `purejl` and `psgo` locate user-supplied FFI by the *same rule
purs already uses for `.js`*: a foreign file **co-located with the `.purs`**,
discovered via CoreFn `modulePath`. This removes purejl's arbitrary `ffi-jl/`
directory + underscore-mangling, and gives psgo a user-foreign mechanism it
lacks entirely today.

Only **discovery** is harmonized. File **contents** stay target-specific
(Julia `include`-style bare names vs Go `package main` module-qualified vars) —
that difference is essential, not arbitrary.

## Why this is correct (evidence)

- purs: `Foo.js` sits next to `Foo.purs` (the convention every PS dev knows).
- purejl today: `copyUserForeigns` is `glob "ffi-jl/*.jl"` (Make.hs ~L178) —
  ignores the source location entirely; the flat dir forces names like
  `Data_Quantity_Julia_foreign.jl`.
- psgo today: no user-foreign path at all. It embeds its shim catalogue in
  `runtime/prelude.go`, only prints `FOREIGN <module>`, then `go build` fails
  with `undefined: <Module>_<name>`.
- CoreFn JSON carries `modulePath`, confirmed even for a *local path-package*
  module: `modulePath = ../../core/src/Runtime.purs`. Both backends already
  have `CoreFn.modulePath` on every module in their emit loop. They simply
  don't use it.

## Convention (decided — implement exactly this)

- **Foreign file location**: same directory as the `.purs`, basename with the
  extension swapped. `Runtime.purs` → `Runtime.jl` (purejl) / `Runtime.go`
  (psgo). **Bare name, no `_foreign` suffix** — match purs's `Runtime.js`.
- **Resolution**: `dropExtension (CoreFn.modulePath m) <> ".jl"` (resp. `.go`),
  resolved relative to CWD. The backend is invoked from the project root (same
  assumption purs makes), so the relative `modulePath` resolves directly.
- **Contents unchanged**: purejl foreign = bare-name defs `include`d into the
  generated module (`runtimeName = "Julia"`); psgo foreign = `package main`
  with the module-qualified symbol psgo already references
  (`var Runtime_runtimeName any = "Go"`).

## Toolchain note (both repos)

GHC 9.2.5 is installed (`~/.stack/programs/aarch64-osx/ghc-9.2.5.installed`).
Build with a plain **`stack build` from the repo root**. Do NOT use
`stack exec --stack-yaml <abs-path> …` — that spuriously triggers a missing
`ghcup` install hook. Run the rebuilt binary as
`$(stack path --local-install-root)/bin/<purejl|psgo>` or via the prebuilt
path already on disk after `stack build`.

---

## Change A — purejl

- **Repo**: `/Users/afc/work/afc-work/purescript-backends/purescript-julia`
- **File**: `src/Language/PureScript/Julia/Make.hs`
- **Change**: make foreign copying **module-driven**. For each emitted module
  with foreign imports (`not (null (CoreFn.moduleForeign m))`), resolve the
  co-located `dropExtension (CoreFn.modulePath m) <> ".jl"`. If it exists, copy
  it to `outputDir </> jlForeignFileName mn` (the `include` target name — leave
  the include machinery in `moduleFile` untouched).
- **Back-compat**: keep the existing `ffi-jl/*.jl` glob as a **fallback** used
  only when no co-located file is found. This keeps the 11 examples and
  `bin/conformance.sh` green.
- The existing "has foreign imports but no shim" warning must NOT fire when a
  co-located file was copied.
- **Verify**:
  1. `bin/conformance.sh` stays GREEN (exercises the `ffi-jl/` fallback).
  2. Co-location works on a fresh fixture (see Acceptance below).

## Change B — psgo

- **Repo**: `/Users/afc/work/afc-work/purescript-backends/purescript-go`
- **File**: `src/Language/PureScript/Go/Make.hs`
- **Change**: after `emitMods`, for each module with foreign imports resolve the
  co-located `dropExtension (CoreFn.modulePath m) <> ".go"`. If it exists, copy
  it into `outputDir` as a sibling `package main` file (e.g.
  `<basename>_foreign.go`) and `gofmt` it (reuse `gofmtInPlace`).
- The runner must include the copied files: emit/run with **`go run *.go`**
  (not `go run main.go prelude.go`). Update psgo's printed run hint accordingly.
- Co-located lookup is **additive** — stdlib library modules (console, etc.)
  have no co-located `.go`, so nothing changes for them; they keep using the
  embedded `prelude.go` shims.
- Improve the gap signal: only warn for a foreign module when **no** co-located
  `.go` was found (psgo can't cheaply tell a stdlib shim from a real gap, so
  word it as "no co-located <Module>.go — relying on an embedded shim or this
  will fail to build").
- **Verify**:
  1. Corpus conformance (`backend-go/run_conformance.sh`, or `test-suite`)
     stays at its documented baseline (co-location is additive; no `.go`
     fixtures present → unchanged).
  2. Co-location works on a fresh fixture (see Acceptance below).

---

## Acceptance (each agent builds its OWN throwaway fixture — do not share state)

A minimal program with one user foreign, built and run end-to-end:

```
# Main.purs (pure): main = log ("on " <> runtimeName <> ".")
# Runtime.purs:     foreign import runtimeName :: String
# Runtime.<ext> co-located next to Runtime.purs (NOT in ffi-jl/, NO manual copy)
spago build            # backend.cmd: "true", packageSet registry 57.1.0
<backend> output output-<ext> [--entry Main for psgo]
<runner>               # julia output-jl/main.jl   |   (cd output-go && go run *.go)
# expected stdout: "on Julia." / "on Go."
```

PASS = the co-located foreign is picked up automatically (no `ffi-jl/`, no
manual file copy) AND the in-repo conformance suite is unregressed.

## Out of scope / follow-ups (do not do here)

- Migrating the 11 Jurist examples off `ffi-jl/` onto co-location.
- Updating `polyglot-template`'s examples to drop per-column `ffi-jl/` /
  `ffi-go/` dirs (foreigns then co-locate at the seam; columns become pure
  build-recipes).

**Do NOT git-commit.** Implement, build, run the acceptance check, and report.
