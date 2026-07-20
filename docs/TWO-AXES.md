# Two axes of one layout

*Design record — the pappardelle generalization session, 2026-07-20.*

The B layout was built for one story: **the same program on many runtimes.**
A real worked example (Nyx's capstone — Quartermaster's toolchain recipe,
authored in PureScript and compiled to Nix) turned out to fit the *same
directory shape* while telling the *dual* story: **one value, many
interpretations.** This document generalizes the charter to admit both, under a
single concept, without loosening the two rules that make the layout worth
having.

## The two stories

**Program axis** — *the same program on many runtimes.*
`core/` holds the program (behaviour). Each runtime is a complete standalone
target. Per-runtime specificity lives at the FFI seam: one foreign declaration
in `core/`, a co-located implementation per runtime (`Runtime.{js,jl,go}`).
Behaviour is fixed; the runtime varies. *(examples/hello, examples/runtime-name)*

**Data axis** — *one value, many interpretations.*
`core/` holds a value (data). Each interpreter folds that value into a different
artifact: Nix, Markdown, a graph, a belief set. Per-interpretation specificity
lives in the fold. Data is fixed; the behaviour varies. *(examples/interpret;
in the wild, `quartermaster/provisioning/recipe`)*

These are genuine duals — behaviour-fixed/runtime-varies vs
data-fixed/behaviour-varies. The old charter *excluded* the second explicitly
("not heterogeneous systems with different components on different runtimes").
But the exclusion was about **semantics**, not **structure**: the structure —
one shared core, append-only columns, a co-located seam, a `poly` dispatcher —
transfers unchanged.

## The unifying concept: a column is a *lowering of core*

> A **column** is one lowering of `core/`. It pins a package set and a backend
> (which may be a spago backend *or* a post-CoreFn compiler), it may add its own
> PureScript that imports `core` (but never another column), and it yields a
> deliverable — an **execution** on a runtime, or an **emitted artifact** from
> an interpretation.

Two populations of the one concept:

| | **runtime column** | **interpreter column** |
|---|---|---|
| core holds | the program (behaviour) | a value (data) |
| the per-column bit | a co-located foreign in `core/` at the seam | a PureScript fold in the column |
| the deliverable | an execution (`node`, `julia`, native binary) | an emitted artifact (`.nix`, `.md`, a graph) |
| variation lives in | the FFI implementation | the interpreter body |
| story | same program, many runtimes | one value, many interpretations |

The asymmetry in "where the per-column code lives" is not arbitrary — it is
forced by **how each backend resolves symbols**:

- A **foreign implementation** *must* sit co-located with the `.purs` it
  implements — that is the one resolution rule every backend already obeys
  (purs finds `.js`, purejl finds `.jl`, psgo finds `.go`, all via CoreFn
  `modulePath`). It cannot live in the column.
- An **interpreter** is an ordinary module that *imports* `core` and folds its
  data. It naturally lives in the column, and it *must* — keeping it out of
  `core/` is what lets `core/` stay backend-neutral (Prim-only data compiles
  under every backend at once; an interpreter that emits Nix does not).

Both obey the two rules unchanged: a column never edits `core`'s shared modules
and never touches another column; the co-located foreigns are per-runtime
*additions at the seam*, not edits to shared logic.

## The four decisions (from #239 note 503), resolved

**(a) May a column carry logic, not just a `spago.yaml` build-recipe?**
**Yes** — an *interpreter column* is exactly that: `columns/<name>/src/*.purs`
importing `core` and folding it. The isolation rule keeps append-only intact: a
column's PureScript may import `core`, never another column. (Runtime columns
stay thin — their logic is in `core`; the column is just a recipe plus, at most,
a stub package module.)

**(b) May a column's backend be a post-CoreFn compiler, not a spago backend?**
**Yes — and this was already true.** `purejl` and `psgo` are *already*
post-CoreFn compilers here: their `spago.yaml` sets `backend: { cmd: "true" }`
(compile to CoreFn, do no JS codegen) and `poly`'s case-arm runs the real
compiler on `output/`. **Nyx (`pursnix`) is structurally identical to the `go`
column**: `spago build` → CoreFn, then `pursnix output <dst>` → `.nix`. So the
nix column's build-recipe is `purs → corefn` + `pursnix`, and it has a home in
the *existing* convention — it is one more `case` arm, which is the append-only
story. No new column convention was needed; only the recognition that a
"backend" here has always meant "the tool `poly` runs after CoreFn."

**(c) Portability semantics for the dual.**
Program axis: `Primary | Maybe | Never` over *(capability × runtime)*, a meet
over the FFI a program actually uses. Data axis: the same lattice over
*(IR-shape × interpreter)* — an interpreter is `Primary` on the constructors it
folds, `Never` on those it cannot (e.g. a `toGraph` that renders `Shell` and
`Package` but has no rendering for `Bundle` is `Never` on `Bundle`). The
portability of a *value* under an interpreter is the meet over the constructors
that value actually contains. Same lattice, same meet, different index set — the
capability question ("does this lowering handle what this core uses?") is one
question on both axes.

**(d) Does `poly` dispatch interpreters like runtimes?**
**Yes.** `poly run <col>` and `poly list` range over *columns*, runtime or
interpreter alike. The only new dimension is that a column has a **kind**:
`run` (execute — node/julia/go) vs `emit` (produce an artifact — nix/docs).
That is one field in the per-column adapter, alongside the backend resolution
`poly` already does. `poly run <interpreter>` emits and prints/locates the
artifact; `poly build <interpreter>` writes it to the deliverable path.

## Why this is the right generalization (and what it buys)

It **subsumes** the original charter rather than bolting a second mode beside
it. "Every runtime feels primary" becomes "every lowering feels primary."
"Append-only / sub-linear" becomes "add a lowering = add a column; cost bounded
by the lowering's own unmet surface, never by the number of existing columns" —
true whether the new column is a runtime or an interpreter.

The concrete payoff, in the recipe that motivated this: today the recipe
compiles *all* of `src/` under the JS backend, so its Nix-only interpreter
(`ToNix.purs`) needs a throwing JS FFI stub (`ToNix.js`) purely so `spago build`
can compile a module it will never run. Under this layout `ToNix.purs` lives in
`columns/nix/` (compiled only by the nix lowering) and `ToDocs.purs` in
`columns/docs/` (compiled only by the JS lowering); `core/` holds just the
Prim-only IR value. **The stub disappears** — it was never a real requirement,
only an artifact of compiling two interpreters under one backend.

## Restructuring the recipe (the first data-axis client)

`quartermaster/provisioning/recipe` maps onto this layout directly:

| recipe today | data-axis column |
|---|---|
| `src/Quartermaster/Recipe/IR.purs` (Prim-only value) | `core/` |
| `src/Quartermaster/Recipe/ToNix.purs` + `ToNix.nix` FFI | `columns/nix/` (emit, Nyx post-CoreFn) |
| `src/Quartermaster/Recipe/ToDocs.purs` + `Main.purs` | `columns/docs/` (emit, JS backend) |
| `ToNix.js` throwing stub | *deleted* |
| `bin/verify.sh` (drvPath equivalence) | `poly`-driven `emit nix` + the same eval |

Do this *after* the template's own worked example is green, so the conventions
are exercised in the small before the load-bearing recipe adopts them.
