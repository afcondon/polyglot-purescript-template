# purs-nix evaluation — for the multi-runtime PS build/realizer architecture

**Date:** 2026-06-19
**Scope:** read-only analysis of the purs-nix clone at
`/Users/afc/work/afc-work/GitHub/local-copies/purs-nix` (no `nix` run, no edits),
evaluated against `bosun/docs/RUNTIME-SPINE-AND-BUILD-LAYER.md`, `polyglot-template`,
and the co-located-foreigns convention.

**Method note.** All file/line citations below were VERIFIED by reading the source.
Where I extrapolate beyond what the source states, I mark it INFER.

---

## 1. What purs-nix is + maturity

purs-nix is **Nix-builds-PureScript**: a Nix library + CLI that compiles/bundles a
PureScript project inside Nix derivations, plus its own PureScript package set
(`README.md` lines 3, 27-44). It is the *inverse* of what our plan authors — we want
PS-to-derivation; purs-nix is Nix-expression-to-PS-build. It is the obvious prior art
for the *realizer* (RUNTIME-SPINE §9), not for the eDSL.

**Maturity / mechanics (VERIFIED):**
- Self-described "currently unstable" but with a long-stable core API and
  backwards-compat intent (`README.md` line 5). Actively maintained by
  Platonic.Systems (`README.md` lines 84-87). CHANGELOG runs 2022→2025-12, recent
  entry is "Added support for the PureScript registry" (`CHANGELOG.md` lines 1-5).
- **Flake-first.** Top-level flake exposes a `__functor` so `purs-nix` is callable as
  `purs-nix { system; pkgs?; overlays?; defaults?; }` (`flake.nix` lines 26-39;
  `docs/purs-nix.md` lines 3-16). Non-flake path via `templates/shell.nix` exists
  (`README.md` lines 14-19).
- **Pins.** `nixpkgs` = `nixpkgs-unstable` (`flake.nix` line 13); `purs`/`spago`
  toolchain via the `ps-tools` input (`flake.nix` lines 14-21), and the compiler is
  fixed to `ps-tools.for-0_15.purescript` (`purs-nix.nix` line 12) — i.e. **PureScript
  0.15**, branch `ps-0.15`. Package set comes from a non-flake `registry` input =
  `github:purescript/registry` (`flake.nix` line 22).
- Tests/examples only gated on `x86_64-linux` (`flake.nix` lines 94-105); darwin
  systems are declared (`flake.nix` line 63) but the example checks don't run there.
  INFER: macOS build path is less exercised.

---

## 2. The six answers

### Q1 — Derivation-level vs expression-level

**purs-nix is expression-level, but those expressions evaluate to ordinary
nixpkgs `stdenv.mkDerivation` derivations — it does NOT expose a `.drv`-emitting
layer.** This is the crux for our plan.

- The user surface is `purs {...}` returning an attrset whose members
  (`output`, `bundle`, `script`, `app`, `test`) are **functions that return
  derivations** (`docs/purs-nix.md` lines 54-65; `docs/derivations.md` lines 1-8).
- VERIFIED how they're built: `output` is `compile-and-process` → `mkDerivation {...}`
  with `buildPhase` running `purs compile` and `installPhase = "mv output $out"`
  (`purs-nix.nix` lines 176-205, 394-421). `bundle`/`script`/`app` wrap that in
  `runCommand`/`mkDerivation` (lines 423-471).
- So the "derivation" is a normal Nix *expression* that the Nix evaluator turns into a
  `.drv`. purs-nix never authors `.drv`/JSON-derivation text itself, and exposes no
  hook below the Nix-language level.

**Consequence for RUNTIME-SPINE §4 / §7 / §9:** our plan wants **PS → `.drv`**, one
level *below* Nix-expression text, precisely so the build region is an introspectable
typed `Data.Graph` value rather than a black box behind the evaluator (§7, the
"decisive reason"). purs-nix sits squarely on the wrong side of that line: it *is* the
black box (a Nix expression you must evaluate). It cannot give us derivation-level
hooks. It can, however, *be* a ready-made realizer if we let Nix own the front for PS
inputs (see Q5 + verdict).

### Q2 — CoreFn / alternative backends — THE CRITICAL ONE

**Partial yes on CoreFn codegen; hard no on an integrated custom backend command.**

- **CoreFn codegen IS reachable.** purs-nix threads `purs compile`'s `--codegen` flag
  all the way through. `utils.compile` builds `--codegen <arg>` via
  `make-flag "--codegen" codegen` (`utils.nix` lines 47-67, esp. 54, 62). `output {}`
  and the `compile`/`command` configs accept `codegen ? null`
  (`docs/derivations.md` lines 9-16; `docs/purs-nix.md` lines 96-105). So
  `output { codegen = "corefn"; }` (or `"corefn,js"`) would make `purs` emit CoreFn
  into the output derivation. **VERIFIED the flag is passed through; not run.**
- **But there is NO backend hook.** Every downstream consumer is hard-wired to JS/Node:
  - `bundle`/`script`/`app` run **esbuild** over `output/<Module>/index.js`
    (`purs-nix.nix` lines 423-471; `utils.nix` lines 7-45) and `script` shebangs
    `${nodejs}/bin/node` (line 446-450).
  - `test.run` runs the output with **node** (`purs-nix.nix` lines 497-507;
    `utils.node-command`, `utils.nix` 102-113).
  - `purescript` is pinned and there is **no `backend` parameter** anywhere — `purs`'s
    args are `dependencies/test-dependencies/dir/srcs/test/test-module/nodejs/
    purescript/foreign` (`docs/purs-nix.md` lines 31-52; `purs-nix.nix` lines 32-41).
    The only post-compile step in `output` is `pp.foreign` (foreign linking,
    `purs-nix.nix` 346-355, 416-420). There is **no place to inject `purejl`/`psgo`**.

**Plain verdict on Q2:** purs-nix can own the *front of a column up to and including
`purs compile --codegen corefn`* (it would produce a derivation containing the CoreFn
tree). It **cannot** own the backend *tail* (transpile + native build/run) — that whole
half is JS/esbuild/node-only with no extension seam. For our Julia/Go columns it is at
best a CoreFn-producing front, never an end-to-end builder.

### Q3 — Dependency / package-set model

- **Its own package set, an extension of the official one** (`README.md` 27-44):
  namespaced packages, no global module namespace, per-package info importable from the
  package's home repo. Dependencies are primarily **strings looked up in `ps-pkgs`**
  (`docs/purs-nix.md` 44; `CHANGELOG.md` 2022-12-12 "Switch dependencies to be
  primarily strings"). The closure is computed in Nix (`create-closure*`,
  `purs-nix.nix` 69-111).
- **Registry support exists** (`CHANGELOG.md` 2025-12-3; `build-pkgs.nix` 32-78;
  `docs/types.md` `RegistryPackageData` 213-232), but as `src.registry.version`/`ref`
  **per package** — it pins individual packages from `purescript/registry`, NOT a
  whole spago `registry: 57.1.0` package-set selection. The base set is the official
  package-sets latest (`utils.get-package-set`, `utils.nix` 172-181), not a registry
  solver. INFER: matching our exact `registry: 57.1.0` closure would require either an
  overlay pinning every package or accepting purs-nix's set — a real reconciliation.
- **It does NOT consume a spago project.** It wants its own description: deps listed in
  the flake's `purs {...}` call (`examples/hello-world/flake.nix` 33-41) and/or a
  `package.nix`-style `Info` (`docs/types.md` 67-114; `package-description.nix`). There
  is no `spago.yaml` reader. `README.md` 53-63 only addresses esbuild-format
  differences when "migrating from spago," not config import.
- **Migration cost from our setup:** non-trivial. Each column today is a `spago.yaml`
  with `packageSet { registry: 57.1.0 }` + a `backend.cmd: "true"` trick
  (polyglot-template README; co-located-foreigns spec lines 102). Adopting purs-nix
  means re-expressing every column's dep list in Nix and reconciling to purs-nix's set.
  That is a parallel source of truth to spago, which cuts against poly's "the column's
  `spago.yaml` carries the build config" design (`bin/poly` 6-12).

### Q4 — FFI / foreign

- purs-nix's foreign model is **JS/Node-only by construction** (`docs/foreign.md`;
  `docs/types.md` `NodeModules`/`ForeignPath` 24-37, 131-138). A module's foreign is
  either `node_modules` (a node_modules dir) or `src` (a dir of JS imported from
  `./foreign/file.js`) (`docs/foreign.md` 5-13). The linker `link-foreign` writes
  `package.json` with `{ "type": "module" }` and symlinks node_modules / a `foreign`
  dir (`purs-nix.nix` 113-164). Both options are JS semantics.
- **Could the model accommodate per-runtime non-JS foreigns?** Not as-is. The
  `foreign` schema (`package-description.nix` 50-65) only admits `node_modules`/`src`
  paths and the linker only does JS-style placement. There is no notion of a
  per-runtime foreign keyed by backend. INFER: it could be *extended* (the
  `link-foreign` step is the only foreign-aware place), but that is a fork, not a use.
- This is also **orthogonal to our convention.** Ours co-locates `Runtime.{js,jl,go}`
  next to `Runtime.purs`, resolved via CoreFn `modulePath` by the backend itself
  (co-located-foreigns spec; polyglot-template README "Per-runtime user-foreign
  convention"). purs-nix's foreign-linking happens *before/around `purs compile`* for
  JS; our non-JS foreigns are consumed *by the backend transpiler after CoreFn*, which
  purs-nix has no concept of. So even the JS column wouldn't share a foreign mechanism
  with the jl/go columns.

### Q5 — Reuse seam

**Yes, there is a clean seam — but only for the CoreFn front, and only if we accept a
parallel package-set source of truth.**

- The natural seam is **purs-nix's `output { codegen = "corefn"; }` derivation**: a
  reproducible `/nix/store` path containing the CoreFn JSON for a project
  (`purs-nix.nix` 176-205, 394-421; `--codegen` passthrough per Q2). `poly build <rt>`
  could, in principle, replace its `spago build` step (`bin/poly` 42) with "realize the
  purs-nix CoreFn derivation," then keep the unchanged tail —
  `psgo output-from-store output-go --entry Main && go build` (`bin/poly` 53-57) or
  `purejl … && julia …` (49-52).
- **But the seam is awkward in three ways:**
  1. **Two package-set sources of truth.** Deps would live in a purs-nix flake *and*
     the column's `spago.yaml`, with no guarantee they pin the same closure (Q3). poly's
     whole premise is "the column's spago.yaml is the recipe" (`bin/poly` 6-12).
  2. **Non-JS foreigns don't ride along.** Our `Runtime.jl`/`Runtime.go` are resolved
     by the *backend* from `modulePath` after CoreFn (Q4) — purs-nix's foreign linking
     is irrelevant/JS-only, so the CoreFn-front derivation must still carry the source
     tree so `modulePath` resolves co-located foreigns. INFER: workable (CoreFn keeps
     `modulePath`, per the spec's evidence section), but purs-nix gives no help here.
  3. **No `.drv`-level introspection.** Even used this way, the build region stays a
     Nix-expression black box — it does NOT advance §7's one-Sankey-graph goal; it only
     gives reproducibility for the PS→CoreFn step.

**Better framed as inspiration than direct reuse** for the eDSL, because the eDSL needs
derivation-level output purs-nix doesn't expose (Q1). For the *realizer* role
(RUNTIME-SPINE §8.4), purs-nix's CoreFn-front derivation is reusable as a black-box step
but earns its weight only if we want Nix reproducibility for the PS compile specifically.

### Q6 — Maturity / mechanics / showstoppers

- Maintained, flake-native, sane pins (see §1). No license issue (MIT-ish `LICENSE`).
- **Showstoppers for our plan:**
  1. **No derivation-level API** — only Nix expressions evaluating to mkDerivations
     (Q1). Directly contradicts the PS→`.drv` requirement (RUNTIME-SPINE §4, §7).
  2. **JS/node-only downstream + no backend hook** (Q2). It can reach CoreFn but cannot
     drive `purejl`/`psgo`; the Julia/Go *tail* is entirely outside it.
  3. **Parallel package-set model** vs our spago `registry: 57.1.0` (Q3) — adoption
     means a second source of truth.
  4. **JS-only foreign model** (Q4), orthogonal to our co-located per-runtime convention.
- **Non-showstoppers / assets:** the `--codegen` passthrough (Q2) proves the cheap path
  to CoreFn exists; the `stdenv.mkDerivation` + `mv output $out` pattern
  (`purs-nix.nix` 199, 313) is a clean, copyable template for what *our* realizer's
  derivation builder should emit for a `purs compile` step. PureScript pinned at **0.15**
  (`purs-nix.nix` 12) — confirm it matches our toolchain (INFER: our backends target
  CoreFn 0.15-era; likely fine, verify).

---

## 3. Verdict

**inspiration-only** (with one narrow optional reuse).

Reasoning, decisive points first:

1. **Wrong level (Q1).** Our architecture's load-bearing choice is PS → `.drv`
   *below* Nix-expression text, so the build graph is an introspectable typed value
   (RUNTIME-SPINE §7, "the decisive reason"). purs-nix offers only Nix expressions that
   evaluate to mkDerivations — it has no derivation-level hook to reuse. Using it would
   reintroduce exactly the evaluator black box §7 exists to remove.
2. **JS/node-only tail (Q2).** It threads `--codegen` so it *can* produce CoreFn, but
   every downstream path (bundle/script/app/test) is esbuild+node and there is **no
   backend command parameter**. It can never own the `purejl`/`psgo` half of our
   Julia/Go columns — the part that makes them "polyglot" at all.
3. **Parallel package-set + JS-only foreigns (Q3, Q4)** make even the partial CoreFn
   reuse a second source of truth alongside our `spago.yaml` + co-located foreigns.

It is **not** "reuse-as-front-realizer" because the front it realizes stops at CoreFn,
introduces a competing dependency model, and stays opaque to the Sankey-graph goal. It
is **not** "not-a-fit" either: it is the canonical reference for *how to wrap
`purs compile` in a reproducible nixpkgs derivation*, and the `output` builder
(`purs-nix.nix` 176-205) is a near-verbatim template for the PS-compile step our own
realizer/eDSL will emit. Mine it for that.

---

## 4. Integration sketch — where purs-nix (or its ideas) sits

```
                            OUR PLAN (RUNTIME-SPINE §3–§4, §8)
  ┌──────────────────────────────────────────────────────────────────────────┐
  │  poly (build driver)                                                       │
  │    columns/<rt>/spago.yaml  ──spago build (codegen corefn)──▶ CoreFn       │
  │    then  psgo/purejl  ──▶ Go/Julia source ──▶ native binary / run          │
  └───────────────┬──────────────────────────────────────────────┬───────────┘
                  │ artifact + content-hash PIN                   │
                  ▼                                               │
  ┌──────────────────────────────┐                               │
  │  Realizer seam (executor)    │   purs-nix lives ONLY here ►   │
  │   • LOCAL realizer (§8.2)    │   as INSPIRATION for the       │
  │   • Nix realizer (§8.4)      │   "wrap purs compile in a      │
  │                              │    reproducible derivation"    │
  │  emits/realises a Derivation │   pattern (purs-nix.nix        │
  │  authored by the PS Nix-eDSL │   176-205, 394-421). NOT a     │
  │  (PS → .drv, §4/§7)          │   dependency; a template.      │
  └───────────────┬──────────────┘                               │
                  │ pin = x-bosun.artifact { source, pin }        │
                  ▼                                               ▼
  ┌──────────────────────────────────────────────────────────────────────────┐
  │  Bosun (deploy + process) — consumes the artifact pin, reconcile/apply     │
  └──────────────────────────────────────────────────────────────────────────┘
```

- **poly** stays the build driver; keeps `spago build` + backend transpile (`bin/poly`
  42-57). purs-nix does NOT replace this — it can't drive the backends.
- **The eDSL / realizer** is where Nix enters. The eDSL authors `Derivation` values in
  PureScript (PS → `.drv`); the realizer (LOCAL first, Nix later) realises them.
  purs-nix's *value to us is here, as inspiration*: its `output` derivation is the
  reference shape for the `purs compile`-step derivation our eDSL must emit.
- **Bosun** is unchanged: it consumes the content-hash pin (the build↔deploy seam,
  RUNTIME-SPINE §3 "join at the artifact pin"), regardless of who realized the artifact.
- **Optional narrow reuse (only if desired later):** behind the *Nix* realizer seam,
  for a *node* column specifically, one *could* shell out to a purs-nix-produced
  `output`/`bundle` derivation. For jl/go columns it offers nothing past CoreFn.

---

## 5. Does it change the planned spike?

**No — do the spike FIRST, exactly as RUNTIME-SPINE §8.3 / §9 already sequence it.**

The spike (hand-emit one `.drv` for the `hello` Go binary, `nix-store --realise` it)
proves the *front-replace / back-delegate* seam at the **derivation level** — precisely
the level purs-nix does **not** operate at (Q1). Nothing in purs-nix substitutes for, or
de-risks, that spike:

- purs-nix can't hand us a `.drv` to crib (it emits Nix expressions, not `.drv` text),
  and it can't build the Go binary at all (Q2). So it cannot shortcut the spike.
- Doing purs-nix *before* the spike would, as §9 warns, evaluate it "in the abstract"
  against an unproven baseline. This evaluation reinforces that warning: purs-nix's
  whole downstream is the JS/node path we are *not* taking, so its reusable surface is
  only visible once you know the spike's `.drv` shape to compare against.

**Recommended order (unchanged):**
1. Spike: hand-author the Go-binary `.drv`, `nix-store --realise` it (§8.3).
2. Build the LOCAL realizer + `Derivation` model (§8.2).
3. Treat purs-nix's `output` derivation (`purs-nix.nix` 176-205) as the *template* for
   the `purs compile` step when the eDSL/realizer needs to wrap PureScript compilation
   reproducibly — copy the pattern, don't take the dependency.

---

## Appendix — most load-bearing citations

- `--codegen` passthrough (CoreFn reachable): `utils.nix` 47-67 (line 54 default,
  line 62 flag); exposed in `docs/derivations.md` 9-16, `docs/purs-nix.md` 96-105.
- JS/node-only tail, no backend hook: `purs-nix.nix` 423-471 (esbuild bundle/app),
  446-450 (node shebang), 497-507 (node test); `purs` args 32-41 (no `backend`).
- Derivations are mkDerivations, not `.drv`: `purs-nix.nix` 176-205 (`output`/
  `compile-and-process`), 199 + 313 (`mv output $out`), 394-421.
- JS-only foreign model: `docs/foreign.md`; `purs-nix.nix` 113-164 (`link-foreign`,
  writes `{ "type": "module" }`); schema `package-description.nix` 50-65.
- Own package set / registry-per-package: `README.md` 27-44; `build-pkgs.nix` 32-78;
  `docs/types.md` 213-232; base set `utils.nix` 172-181.
- Pins: PureScript 0.15 `purs-nix.nix` 12; nixpkgs-unstable `flake.nix` 13; registry
  input `flake.nix` 22. Darwin checks not gated `flake.nix` 94-105.
