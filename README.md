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
  src/Runtime.js      JS foreign — REAL when node is a target, else a presence-stub
columns/<rt>/
  spago.yaml          the whole per-runtime recipe (package set + backend cmd + path-ref core)
  ffi-jl/  ffi-go/     per-runtime foreign IMPLEMENTATIONS (non-JS backends)
Makefile              run-<rt> targets — makes the multi-column tree feel flat
```

## Per-runtime user-foreign conventions (discovered empirically)
| Runtime | Backend | User foreign goes in | Status |
|---|---|---|---|
| node   | purs (JS)  | `Runtime.js` co-located with `.purs` | native |
| julia  | purejl     | `columns/jurist/ffi-jl/<Module>_foreign.jl` (copyUserForeigns) | native |
| go     | psgo       | `columns/go/ffi-go/<Module>_foreign.go` | **gap: psgo has no copy step yet** — applied by hand for now |

## Examples
- `examples/hello` — pure program, no FFI. Runs on julia + go from one source.
- `examples/runtime-name` — the same `Main` printing a per-runtime string via
  a different foreign each: node/julia native, go one small psgo feature away.
