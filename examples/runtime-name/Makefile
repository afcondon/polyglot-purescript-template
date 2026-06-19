# runtime-name — same Main, a different foreign per runtime.
PUREJL := /Users/afc/work/afc-work/purescript-backends/purescript-julia/.stack-work/install/aarch64-osx/54adb6514a6cae3ce612d3120f8901fb6f9080de7701bf0a5977bb63d1bf3e24/9.2.5/bin/purejl
PSGO   := /Users/afc/work/afc-work/purescript-backends/purescript-go/.stack-work/install/aarch64-osx/54adb6514a6cae3ce612d3120f8901fb6f9080de7701bf0a5977bb63d1bf3e24/9.2.5/bin/psgo

run-node:
	cd columns/node && spago build && node --input-type=module -e 'import("./output/Main/index.js").then(m=>m.main())'

run-jurist:
	cd columns/jurist && spago build && $(PUREJL) output output-jl && julia output-jl/main.jl

run-go:
	cd columns/go && spago build && $(PSGO) output output-go --entry Main && 	  cp ffi-go/Runtime_foreign.go output-go/ && (cd output-go && go run *.go)
