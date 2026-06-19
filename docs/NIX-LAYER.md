# The Nix layer — grounding the runtime-spine in polyglot-template

**Status:** DESIGN + a running zero-Nix realizer (2026-06-19). Grounds
`ShapedSteer/bosun/docs/RUNTIME-SPINE-AND-BUILD-LAYER.md` in what now exists
(the `poly` wrapper, the column build DAG, co-located foreigns). No Nix is
installed on the dev machine yet; this captures the design + the part we *can*
run now, so the hands-on Nix spike is ready to pick up later.

## 1. What Nix is here (and isn't)

Nix is **a resolver of content-addressed file references**, not a container.

- A **container** reproduces by *enclosure* — ship the world in an image,
  isolate it at *runtime*. Coarse-grained; the image is an opaque blob.
- **Nix** reproduces by *exact reference* — every file is a `/nix/store/<hash>`
  path; a "closure" is the precise transitive set of paths a thing references.
  Fine-grained; the closure is a **graph you can inspect**. Nix-built binaries
  run as ordinary host processes pointing at pinned paths.
- Nix *borrows* container-style isolation only at **build** time (the sandbox,
  to forbid reaching anything un-pinned). Isolation is a means; the end is the
  reference graph. (Nix can even *produce* container images.)

**Why this is the whole point.** A closure *is* a `Data.Graph`; a container
image is a black box. The reference-graph nature is exactly what makes the
build region introspectable — the prerequisite for the one-Sankey-chart goal
(RUNTIME-SPINE §1, §7). Hence: **delegate the back** (`/nix/store` + sandbox,
reused like the OS) but **replace the front** (emit a typed `.drv` we can graph,
not Nix-expression text).

## 2. Executor-axis placement

`nix-store --realise` is a **realize** executor (code → artifact, the *build*
edge). `docker | launchd | process` are **run** executors (artifact → running
process, the *deploy/run* edge). Nix does not compete with Docker — it sits one
phase upstream. Same `{source, pin}` artifact joins the two edges (Bosun's
`x-bosun.artifact`).

## 3. The column build DAG (what the B layout hands us for free)

```
core/ + pkgset ──(purs/spago)──▶ CoreFn ──┬─(psgo + go)─────▶ go binary
                                          └─(purejl + julia)─▶ julia artifact
node column:   core/ + pkgset ──(purs JS)────────────────────▶ node bundle
```

One CoreFn **front** fans out to N backend **tails** — a tiny but complete
instance of the build DAG. `poly` is the imperative interpreter of this DAG
today; the typed `Derivation` eDSL is its declarative twin.

**The hermeticity boundary is the spago fetch.** `spago build` downloads the
registry package set at build time — that is the one impure step. So:

- The **tail** (CoreFn → backend → artifact: `psgo`/`purejl` + `go`/`julia`)
  is naturally hermetic — fixed inputs, no network. This is *our* novel work,
  and the clean part.
- The **front** (PS → CoreFn) is the harder, *already-solved-elsewhere* problem
  (pre-fetch the package set into the store; this is what purs-nix / spago2nix
  do). Defer it; vendor a pre-fetched `.spago` as a fixed-output derivation for
  the spike.

## 4. Two realizers behind one seam

| realizer | status | how |
|---|---|---|
| **local** (zero Nix) | **running now** (`poly pin <rt>`) | build + content-hash → a pin manifest; provenance = tool versions. Proves the code→artifact→pin seam; emits the `{source, pin}` Bosun consumes. |
| **Nix** | future (needs install) | `nix-store --realise` a derivation; `inputs` become store paths. *Same pin shape* — slots in behind the same seam. |

`poly pin` (the local realizer) is RUNTIME-SPINE §8.2, grounded. A pin:

```json
{ "runtime": "go",
  "source": { "project": "runtime-name", "column": "go", "entry": "Main" },
  "inputs": { "purs": "...", "spago": "...", "packageSet": "registry:57.1.0",
              "backend": "psgo", "backendBin": "...", "runtimeTool": "go1.25.3" },
  "artifact": { "kind": "file", "path": "columns/go/go-bin", "sha256": "...", "bytes": N } }
```

## 5. purs-nix — verdict: inspiration-only

Full evaluation: `docs/research/purs-nix-evaluation.md`. Decisive points:

- **No `.drv`-emitting API** — its outputs are Nix *expressions* evaluating to
  `mkDerivation`; no hook below the evaluator. It is the black box §7 exists to
  remove.
- **JS/node-only tail** — it threads `--codegen corefn` (so it *could* build the
  front to CoreFn), but has **no `backend` parameter** and every downstream path
  is esbuild + node. It can never drive `purejl`/`psgo`.
- Reuse: copy its `output` derivation *shape* (the "wrap `purs compile`
  reproducibly" pattern) for our own realizer; do **not** take the dependency.

## 6. The spike (authored now, run when Nix is installed)

RUNTIME-SPINE §8.3, sharpened by §3: prove the **tail** hermetically first.

> Given a CoreFn dir, a derivation that pins `psgo` + `go`, runs the transpile +
> `go build`, and `nix-store --realise`s the `hello` Go binary — reproducibly.

How the backend binary enters Nix: **fixed-output derivation** wrapping the
prebuilt `psgo` (trusts provenance; fine for the spike). Full hermeticity later
via haskell.nix/stack-to-nix if/when it earns its weight. A draft lives at
`spike/flake.nix` (UNTESTED — a starting point, not a working build).

Sequencing: do the spike **before** leaning on purs-nix; it cannot shortcut it
(can't hand us a `.drv`, can't build the Go binary). The spike answers "does our
seam hold?"; the local realizer (§4) already answers "does the pin seam hold?"
— yes.

## 7. How the pieces fit

```
poly  ──emits──▶  typed Derivation (eDSL)  ──realise──▶  pinned artifact  ──▶  Bosun (deploy+process)
 (build driver)      (replace the front)    local now / Nix later        Quartermaster = host provision/verify
purs-nix: NOT in the pipeline — a reference for the "wrap purs compile" shape.
```
