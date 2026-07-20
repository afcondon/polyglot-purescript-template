# interpret — the DATA axis: one Prim-only `catalog` value (core/), two
# interpreter columns that fold it. docs -> Markdown (JS backend); nix -> an
# evaluable Nix attrset (Nyx / pursnix, a post-CoreFn compiler). The SAME value,
# two lowerings — the dual of runtime-name's same-program-many-runtimes.
#
# Driven by the bundled `poly`, which dispatches interpreter columns exactly as
# it dispatches runtimes (see ../../docs/TWO-AXES.md).
POLY := ../../bin/poly

run-docs:
	$(POLY) run docs

run-nix:
	$(POLY) run nix

run-all:
	$(POLY) run all
