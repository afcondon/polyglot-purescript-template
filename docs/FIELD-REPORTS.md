# Field reports

What happened when real projects tried to adopt this layout. One entry per
project: what fit, what didn't, and what the template would have to say for it
to fit.

The template has three toy examples (`hello`, `runtime-name`, `interpret`) and
no field use. These are the difficulties, which are the point — a layout that
has only ever been applied to its own examples has not been tested.

---

## grid-explorer (purescript-python) — 2026-07-30

**What it is.** A Flask API over pandapower: N-1 contingency, cascading
failure, topology metrics on the IEEE 30-bus case. Restructured from a flat
`src/` + `ffi-py/` into core + columns as part of a credibility repair (the
analysis had been 660 lines of Python under 297 lines of PureScript type
aliases).

**What fit, and fit well.** The central rule — *core holds the program, the
seam holds the foreigns, all variation pushes to the seam* — was exactly the
right instrument. "Core is FFI-free" and "the seam contains only library calls"
turn out to be the same constraint stated twice, and adopting the layout made
the regression that had happened here visible as a structural fact rather than
a judgement call. The repair and the conformance were one piece of work, not
two.

`backend: cmd: "true"` also did its job silently and well: purs emits CoreFn,
JS codegen is skipped, purepy runs over `output/` afterwards. No bogus JS
companion was needed anywhere, for any of the seam's foreign imports.

### Finding 1 — `purepy` is missing from `docs/specs/co-located-user-foreigns.md`

**Blocking for full conformance.** The spec harmonises `purejl` and `psgo` onto
purs's co-location rule (`Foo.py` beside `Foo.purs`, discovered via CoreFn
`modulePath`) and calls the flat-directory alternative "arbitrary". `purepy`
has exactly the same arbitrary mechanism and the spec does not mention it:

```haskell
-- purescript-python/src/Language/PureScript/Python/Make.hs:183
copyUserForeigns outDir = do
  let ffiDir = "ffi-py"
  files <- glob (ffiDir </> "*.py")
```

Same consequence as purejl's `ffi-jl/`: the flat directory forces mangled names
(`Grid_Solver_foreign.py` rather than `Solver.py`), and the foreign cannot sit
beside the `.purs` it implements. So a Python column **cannot** satisfy the
template's co-location rule today.

**What the template needs:** a Change C in that spec, identical in shape to
Changes A and B — resolve `dropExtension (CoreFn.modulePath m) <> ".py"`, keep
the `ffi-py/*.py` glob as a fallback so existing examples stay green.

**Worked around by** keeping the foreigns in `columns/python/ffi-py/`. Putting
them in the column rather than at the repo root is at least *per-runtime
specificity in the per-runtime place*, which is the spirit if not the letter.

### Finding 2 — columns cannot really be recipe-only

The program-axis layout says `columns/<rt>/spago.yaml` is "the WHOLE
per-runtime recipe — a pure build-recipe, no foreigns", implying no source in a
column. That did not survive contact: a real program needs an **entry point**,
and the entry point is genuinely per-runtime (here, the Flask route table;
`Main.purs` is 60 lines of HTTP surface that means nothing to any other
runtime).

Note the template is already out of step with its own sibling project on this —
`stability-atlas` has `parity-jl/src/Main.purs`, `parity-node/src/Main.purs`
and `service/src/Main.purs`, i.e. source in every column.

**What the template needs:** say that a column may carry an entry point (and
only an entry point), or explain where the entry point is supposed to live if
not there. The current wording reads as a prohibition that no real program can
observe.

**Resolved as** `columns/python/src/Main.purs` — routes only, with a comment
saying that analysis appearing there means it has escaped the core.

### Finding 3 — nothing about a parity column over a single-runtime library

The FFI-free-core rule buys something valuable that the template never cashes
in: the analysis modules compile under the stock JS backend, so a differential
parity column is available for free — which is precisely the discipline
`stability-atlas` runs (`parity-node` diffed byte-for-byte against `parity-jl`).

But pandapower exists on Python and nowhere else. A node column cannot
implement `Grid.Solver`, so it can only compile the FFI-free *subset* — which
is what `parity-node` actually does (it compiles `Atlas.Protocol.Tests`, not
the whole service).

The template has no vocabulary for that: its columns are whole-program
lowerings, all-or-nothing. A "parity column over the FFI-free subset" is a
different and useful thing.

**What the template needs:** name it. Something like a *partial column* — a
column that depends on core but selects the FFI-free modules, exists to prove
cross-runtime agreement rather than to ship, and is available to any project
whose core is genuinely FFI-free. This is the strongest argument for the
FFI-free rule and it is currently left implicit.

**Not built here** — noted as available. The core is FFI-free, so it costs only
a `columns/node/` recipe whenever it is wanted.

### Aside, not a template finding

`Grid/Graph.purs` wanted `Data.Map` and could not have it: purepy miscompiles
the recursive local binding in `Data.Map.Internal`, so importing it kills the
program at import time. Filed as
`purescript-python/docs/RECURSIVE-LET-BINDING-ISSUE.md`. Mentioned only because
it shaped the code — the module uses association arrays and linear scans, and
says so.

---

## purerl-tidal's engine (node + erlang) — 2026-10-01

**What it is.** Tidal's patterns, mini-notation and line language: 23 modules,
about 5,000 lines, consumed by purerl-tidal on the BEAM and by Triggerfish in
the browser, and held to Haskell Tidal by a GHCi oracle. Moved into this
layout as `purerl-tidal/engine/` (`core/`, `columns/node`, `columns/erlang`)
so that Triggerfish could stop vendoring a copy that had drifted from both.

**What fit.** The layout, and the claim it makes possible: the engine's
conformance suite runs in both columns, and GHC, the BEAM and JS give the same
answers on every case (111 against GHC, 97 against Tidal). JS passed the first
time it ran, untouched. The seam rule held too: one module has foreigns
(`Haskell.Double`), and everything above it is PureScript.

### Finding 1 — the first core with real dependencies, and package-set skew

The examples import the Prelude. This core imports parsers, maps, rationals,
Unicode classes and maths, and the purerl package set (erl-0.15.3, the newest
there is, from 2022) and the registry disagree on three of them:

| Library | purerl set | registry |
|---|---|---|
| `parsing` | 6: `Text.Parsing.Parser` | 11: `Parsing`, another API |
| maths | `Math` | `Data.Number` |
| `Data.Rational` | `type Rational = Ratio Int` | `newtype Rational (Ratio BigInt)` |

The same source cannot import either side of any of them. **The rule that
worked: core depends on a package only if the API it uses is the same in
every column's set.** Everything else, core owns: its own Parsec, its own
`Rational`, its own `Double` functions, each at most a few hundred lines.

**What the template needs:** say that core's dependencies are the
intersection of the columns' package sets, and that a column's set is part of
its recipe, not a detail. A core that only imports the Prelude never meets
this, so the examples cannot show it.

### Finding 2 — a registry package can cross by being ported, not stubbed

`js-bigints` (the registry's `JS.BigInt`) is JS-only and needs
`Data.Reflectable` and `Parity`, which the purerl set lacks. Rather than a
second BigInt for the BEAM, it was ported: upstream's `.purs` less two
functions, with a `BigInt.erl` beside it (`purerl-tidal/vendor/js-bigints`),
which is how the purerl organisation's own `-erl1` packages are made. Core
names `js-bigints`; the node column resolves it from the registry and the
erlang column to the port. The column's `extraPackages` is where a
per-runtime package lives — another case of Finding 2 in grid-explorer's
report, that columns are not quite recipe-only.

### Finding 3 — divergence from the standard libraries, flagged by name

The engine must be *bug-compatible* with a Haskell library, which sometimes
means meaning something other than PureScript's standard libraries: Haskell's
`Int` wraps at 64 bits (Tidal's randomness depends on it), `Integer` is
unbounded, `round` is banker's, Parsec's `string` consumes what it matched.
The rule adopted: **such a divergence is always visible in the code, as an
import of a module named for the reference** (`Haskell.Int`,
`Haskell.Parsec`; in time perhaps `Julia.*` or `Go.*`), whose specification
is "what the reference does", held to the reference by an oracle (here, cases
GHC evaluates into a golden file). It earns a module only if the reference's
own outputs show the difference; error wording and speed are documented
differences instead. The oracle earned its keep at once: it found two bugs in
the Parsec port before the PureScript side had run.

**What the template needs:** probably nothing yet. Noted because it is the
first reference-semantics library in the ecosystem and the template is where
the next one will look.

### Finding 4 — the conformance suite belongs in core, the entry point in the column

A column cannot run its dependency's `test/`, so the suite moved into core as
a pure module (`Tidal.Conformance`, with its goldens), as `Reef.Conformance`
already does in reef, plus a small `Main` that prints and throws. Each column
carries a one-line `Main` that calls it, because a module named `Main` in
core would collide with its consumers' own. Supports grid-explorer's
Finding 2: a column may carry an entry point, and here it carries nothing
else.

### Finding 5 — the erlang column at scale

Two things the `runtime-name` example never exercised, now in `poly`'s new
erlang arm (9f77dd5) and in `ERLANG-COLUMN.md`:

- **erlc one file at a time.** A batched `erlc ... {} +` stops at the first
  failure and leaves every later module unbuilt. The symptom is `undef` at
  run time, far from the cause: here `data_maybe@ps:Just`.
- **`-disable-feature maybe_expr`.** OTP 27 made `maybe` a keyword, and
  purerl's `Data.Maybe` defines a function of that name, so any program that
  reaches `Data.Maybe` fails to compile without it.

Also confirmed: spago ignores a nested workspace, so columns can live inside a
repo that is already a spago workspace (purerl-tidal's root build is
unchanged by `engine/columns/*`).
