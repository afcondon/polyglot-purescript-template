# The Erlang (purerl) lowering — recipe, and the lessons that shaped it

The erlang column (`examples/runtime-name/columns/erlang/`) is the append-only
lowering to the BEAM: the same FFI-free `core/` `Main.purs`, a co-located Erlang
foreign at the seam (`core/src/Runtime.erl`), and a thin build recipe. It runs:

```
$ nix develop <quartermaster>#purerl -c make run-erlang
Hello from PureScript — running natively on Erlang (BEAM).
```

It is different from the other runtime columns in one way that matters and one
that doesn't: it needs a *real* post-CoreFn backend (`purs-backend-erl`, run
*during* `spago build`, unlike go/jurist's CoreFn tools) — but its FFI still just
co-locates with the `.purs`, exactly like `Runtime.js`. The seam is unchanged; the
build recipe is where the erlang-specific facts live.

This column was not designed up front. It was **dogfooded into existence** by
building a real Erlang-lowered project — [purerl-tidal](../../music/live-coding/purerl-tidal)
(~15 FFI foreigns, live) — on a fresh machine (the mac-mini) and feeding every
failure back as a requirement. *Quartermaster and Brunel taught Pappardelle what
its erlang lowering must be.* Each lesson below is a failure we actually hit.

## The recipe

1. **The FFI foreign co-locates with the `.purs`, named `<module>@foreign`.**
   `core/src/Runtime.erl` sits next to `Runtime.purs` (like `Runtime.js`), but its
   *module* is `runtime@foreign`, **not** the filename. `purs-backend-erl` finds it
   and emits it into `output-erl/Runtime/runtime@foreign.erl`. `@ps` = generated,
   `@foreign` = your co-located FFI, pulled in free.

2. **The backend is npm-provided.** `spago.yaml`'s `backend.cmd` is
   `node_modules/.bin/purs-backend-erl`; a `package.json` declares it. This is the
   one runtime-axis column that needs a `node_modules` to *build* (not to run).

3. **The package set is the purerl set**, not the JS registry:
   `purerl/package-sets/erl-0.15.3-20220629`. `core`'s bare deps (prelude, effect,
   console) resolve from it — `core` stays backend-neutral; the column picks the set.

4. **`purs-backend-erl` emits a NESTED tree** — `output-erl/<Module>/<module>@*.erl`
   — so `erlc` is driven by `find output-erl -name '*.erl'`, never a flat glob.

5. **rebar3 is DEPS-ONLY.** The app (the `@ps`/`@foreign` modules) is compiled by
   `erlc`, never rebar3 — because the `@foreign` files' module names deliberately do
   not match their filenames, which rebar3 rejects. When the project *has* Erlang
   deps (cowboy/ranch/…), set `{project_app_dirs, []}.` in `rebar.config` so rebar3
   fetches+builds only the deps and never touches the app source. (The minimal
   column has no Erlang deps, so no rebar3 at all.)

6. **The devShell contract:** erlang + purs + spago + node/npm + **git** (spago
   shells out to git). This is `quartermaster#purerl`.

7. **The artifact is portable BEAM.** `ebin/*.beam` is platform-independent
   bytecode — so an erlang lowering can be *built once and copied* to any box
   (Brunel's CopyClosure), unlike a native binary.

## The lessons — each failure is a requirement in disguise

| We hit | Where | The requirement it became |
|--------|-------|---------------------------|
| `rebar3` rejected `src/Tidal/Odonus.erl`: *module 'tidal_odonus@foreign' /= file 'Odonus'* | purerl-tidal, on the mini | Recipe §5: rebar3 is deps-only (`project_app_dirs, []`); erlc owns the app. The `@foreign`≠filename convention is load-bearing, not incidental. |
| `spago build` → *Failed to find git* | quartermaster `#purerl` shell | Recipe §6, **and a quartermaster fix** (`671f256`): the `purescript` shell already carried `pkgs.git` "not assumed on fleet hosts" — the lesson existed but never propagated. A devShell has a contract only a real build exercises. |
| `erlc output-erl/*.erl` → *no such file* | this column's first build | Recipe §4: the output tree is nested; `find`-drive erlc. Harvested *here*, live. |
| CopyClosure of `ebin/` to the mini just worked | Brunel | Recipe §7: BEAM is portable — a distribution property that feeds delivery-channel choice (ADR 0007). Brunel taught this back. |
| A batched `erlc ... {} +` built 251 of 273 modules, silently; the run died with `undef` on `data_maybe@ps:Just` | purerl-tidal's engine column | erlc one file at a time, and stop the column on any erlc error (poly's erlang arm). |
| `data_maybe@ps.erl: syntax error before: 'maybe'` | the same, on OTP 27 | `erlc -disable-feature maybe_expr`: `maybe` became a keyword, and purerl's `Data.Maybe` defines one. |

## The meta-lesson

We are learning as we go, and that is the method, not a shortfall. A piece used in
anger (quartermaster provisioning a purerl build; Brunel shipping it cross-machine)
surfaces facts that no up-front design would have — and those facts are the
*requirements* for the next piece. The erlang column is what purerl-tidal +
quartermaster + Brunel knew, made explicit and append-only, so the next
Erlang-lowered project inherits it instead of re-discovering it on a cold box.
