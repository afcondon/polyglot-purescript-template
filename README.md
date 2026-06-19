# polyglot-template (Marginalia #239)

A principled directory layout so **one PureScript program is fully implemented
on whatever runtime it chooses** — not "different components in different
runtimes" (heterogeneous systems) but the *same* program, each runtime a
complete standalone target chosen by fitness.

Lineage: Kevin Jameson, *Multi-Platform Code Management* (O'Reilly, 1994).
His shared source still carried per-platform `#ifdef`; ours carries **zero**
per-runtime branching — all runtime-specificity is pushed to the FFI seam.

## Two rules
1. **Every runtime feels primary.** A no-friction path to a single-runtime
   program on any runtime (home ≠ node).
2. **Extending is append-only / sub-linear.** Adding a runtime may add
   `columns/<rt>/` and per-runtime foreigns; it may never edit `core/`, a pure
   module, or another column. Cost ∝ the program's *unmet FFI surface* on the
   new runtime, not the runtime count.

## Layout (B)
```
core/                 pure source — the only place program logic lives
  src/*.purs          (FFI-free: compiles under every backend)
  src/Runtime.purs    a foreign DECLARATION sits at the seam
  src/Runtime.{js,jl,go}  one foreign per runtime, co-located with the .purs
columns/<rt>/
  spago.yaml          the WHOLE per-runtime recipe — a pure build-recipe, no foreigns
Makefile              run-<rt> targets — makes the multi-column tree feel flat
```

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

## The `poly` wrapper (`bin/poly`)

A thin spago wrapper that "just works" on this layout — the tool ships *with*
the template. The column's `spago.yaml` carries the build config; `poly` only
adds the per-runtime transpile + run glue and discovers which columns a project
has. Run it from anywhere inside a project (it walks up to the `columns/` dir).

```
poly list             # which runtimes this project has + are their backends found
poly run <rt>         # build + run one runtime
poly run all          # run every column; a smoke harness
poly build <rt>       # produce the deliverable (a native binary for go)
```

Backend binaries resolve via `$PUREJL`/`$PSGO`, then `PATH`, then the sibling
`purescript-backends` repos. Adding a runtime = adding one case arm.

## Examples
- `examples/hello` — pure program, no FFI. Runs on julia + go from one source.
- `examples/runtime-name` — the same `Main` printing a per-runtime string via a
  different co-located foreign each. Runs native on node + julia + go.
