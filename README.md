# polyglot-template (Marginalia #239)

A principled directory layout with **one shared `core/` and append-only
`columns/`**, where each column is one **lowering** of that core. The layout
carries two dual stories over the same shape (full design record:
[`docs/TWO-AXES.md`](docs/TWO-AXES.md)):

- **Program axis** — *the same program on many runtimes.* `core/` is the
  program; each column is a complete standalone target (node, julia, go) chosen
  by fitness. Per-runtime specificity lives at the FFI seam. *(examples/hello,
  examples/runtime-name)*
- **Data axis** — *one value, many interpretations.* `core/` is a Prim-only
  value; each column is an interpreter that folds it into a different artifact
  (Nix via Nyx, Markdown via JS, …). Per-interpretation specificity lives in the
  fold. *(examples/interpret; in the wild, Quartermaster's provisioning recipe)*

These are genuine duals — behaviour-fixed/runtime-varies vs
data-fixed/behaviour-varies. The structure — one shared core, append-only
columns, a co-located seam, the `poly` dispatcher — is *axis-independent*.

Lineage: Kevin Jameson, *Multi-Platform Code Management* (O'Reilly, 1994).
His shared source still carried per-platform `#ifdef`; ours carries **zero**
branching in `core/` — all variation is pushed to the seam (runtime axis) or
into the column (data axis).

## Two rules
1. **Every lowering feels primary.** A no-friction path to a single-column
   target — run a program on any one runtime, or emit any one artifact — with
   no ceremony from the others (home ≠ node).
2. **Extending is append-only / sub-linear.** Adding a lowering may add
   `columns/<col>/` (and, on the runtime axis, per-runtime foreigns at the
   seam); it may never edit `core/` or another column. Cost ∝ the lowering's own
   *unmet surface*, never the number of existing columns.

## Layout (B)

**Program axis** — core holds the program; columns are thin recipes; the
per-runtime foreign co-locates at the seam:
```
core/                 pure source — the only place program logic lives
  src/*.purs          (FFI-free: compiles under every backend)
  src/Runtime.purs    a foreign DECLARATION sits at the seam
  src/Runtime.{js,jl,go}  one foreign per runtime, co-located with the .purs
columns/<rt>/
  spago.yaml          the WHOLE per-runtime recipe — a pure build-recipe, no foreigns
```

**Data axis** — core holds a Prim-only value; each column *is* an interpreter
(its own PureScript folding core), so core stays backend-neutral:
```
core/                 Prim-only VALUE — no prelude, compiles under every backend
  src/*.purs          types + the one source-of-truth value
columns/<interp>/
  spago.yaml          package set + backend (JS, or `cmd:true` for a post-CoreFn tool)
  src/*.purs          the interpreter — imports core, folds it to an artifact
  src/<Mod>.nix       (nix column) co-located FFI, exactly like a .js foreign
```
The asymmetry is forced by symbol resolution: a *foreign* must co-locate with
the `.purs` it implements (so it lives in `core/` at the seam); an *interpreter*
imports core and so lives in its column — which is also what keeps `core/`
Prim-only. See [`docs/TWO-AXES.md`](docs/TWO-AXES.md).

## Per-runtime user-foreign convention (harmonized)
One rule, the one purs already uses for `.js`: the foreign sits **co-located
with the `.purs`**, basename + the backend's extension, found via CoreFn
`modulePath`. So `Runtime.purs`, `Runtime.js`, `Runtime.jl`, `Runtime.go` all
live together at the seam; columns hold no foreigns.

| Runtime | Backend | Co-located foreign |
|---|---|---|
| node  | purs (JS) | `Runtime.js` |
| julia | purejl    | `Runtime.jl` (bare-name defs, `include`d into the module) |
| go    | psgo      | `Runtime.go` (`package main`, `var Runtime_<name> any = …`) |

purejl + psgo originally diverged (a `ffi-jl/` glob; psgo had no mechanism at
all). Both were harmonized to co-location — see
`docs/specs/co-located-user-foreigns.md`. (purejl keeps `ffi-jl/` as a
fallback.) Requires the harmonized backends; landed locally, pending upstream.

## Per-interpreter convention (data axis)

An interpreter column pins a backend and folds `core`'s value. Its backend may
be a spago backend (JS) *or* a **post-CoreFn compiler** — the latter is *already*
how `go`/`jurist` work here (`spago.yaml` sets `backend: { cmd: "true" }`;
`poly` runs the real compiler on `output/`), so Nyx slots in as the structural
twin of the `go` arm.

| Interpreter | Backend | Emits | Co-located FFI |
|---|---|---|---|
| docs | purs (JS) | text / Markdown (a `Main` prints it) | `.js` (usually none) |
| nix  | Nyx / `pursnix` (post-CoreFn) | a `.nix` attrset / derivation | `<Mod>.nix` |

Because each interpreter lives in its own column, `spago build` there compiles
*only* that interpreter + `core` — so a Nix-only interpreter needs **no** JS FFI
stub (the thing you'd otherwise write just to satisfy a whole-tree JS build).

## The `poly` wrapper (`bin/poly`)

A thin spago wrapper that "just works" on this layout — the tool ships *with*
the template. The column's `spago.yaml` carries the build config; `poly` only
adds the per-column lower + run/emit glue and discovers which columns a project
has. It dispatches runtime and interpreter columns alike. Run it from anywhere
inside a project (it walks up to the `columns/` dir).

```
poly list             # which columns this project has + are their backends found
poly run <col>        # runtime: build + run;  interpreter: emit + show
poly run all          # run every column; a smoke harness
poly build <col>      # produce the deliverable (native binary for go, .nix for nix)
```

Backend binaries resolve via `$PUREJL`/`$PSGO`/`$PURSNIX`, then `PATH`, then the
sibling `purescript-backends` repos. Adding a lowering = adding one case arm.

## Examples
- `examples/hello` — *(program axis)* pure program, no FFI. Runs on julia + go
  from one source.
- `examples/runtime-name` — *(program axis)* the same `Main` printing a
  per-runtime string via a different co-located foreign each. Runs native on
  node + julia + go.
- `examples/interpret` — *(data axis)* one Prim-only `catalog` value; two
  interpreter columns fold it — `docs` → Markdown (JS), `nix` → an evaluable Nix
  attrset (Nyx). `poly run all` shows both from the one value.
