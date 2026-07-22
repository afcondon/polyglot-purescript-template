# runtime-name — same Main, a different CO-LOCATED foreign per runtime.
# (Runtime.js / Runtime.jl / Runtime.go / Runtime.erl all sit next to Runtime.purs
#  in core/src. The .erl one is module `runtime@foreign`, not the filename — see it.)
PUREJL := /Users/afc/work/afc-work/purescript-backends/purescript-julia/.stack-work/install/aarch64-osx/54adb6514a6cae3ce612d3120f8901fb6f9080de7701bf0a5977bb63d1bf3e24/9.2.5/bin/purejl
PSGO   := /Users/afc/work/afc-work/purescript-backends/purescript-go/.stack-work/install/aarch64-osx/54adb6514a6cae3ce612d3120f8901fb6f9080de7701bf0a5977bb63d1bf3e24/9.2.5/bin/psgo

run-node:
	cd columns/node && spago build && node --input-type=module -e 'import("./output/Main/index.js").then(m=>m.main())'

run-jurist:
	cd columns/jurist && spago build && $(PUREJL) output output-jl && julia output-jl/main.jl

run-go:
	cd columns/go && spago build && $(PSGO) output output-go --entry Main && (cd output-go && go run *.go)

# Erlang (purerl): a REAL backend (purs-backend-erl) runs during `spago build`,
# emitting .erl into output-erl/ — INCLUDING the co-located FFI as runtime@foreign.
# Then erlc compiles output-erl/ to BEAM, and erl runs it. rebar3 is absent here
# (no Erlang deps); at scale it is deps-only (see docs/ERLANG-COLUMN.md). Needs the
# purerl devShell (erlang + purs + spago + node + git) — `nix develop <qm>#purerl`.
run-erlang:
	cd columns/erlang && npm install --silent && spago build && \
	  mkdir -p ebin && \
	  find output-erl -name '*.erl' -exec erlc -o ebin {} + && \
	  erl -pa ebin -noshell -eval 'F = main@ps:main(), F()' -s init stop
# NOTE: purs-backend-erl emits a NESTED output-erl/<Module>/<module>@{ps,foreign}.erl
# tree (the co-located FFI lands as runtime@foreign.erl), so erlc is driven by
# `find`, not a flat glob — a build-detail lesson, harvested here (purerl-tidal
# already knew it). @ps = generated; @foreign = the co-located FFI, pulled in free.
