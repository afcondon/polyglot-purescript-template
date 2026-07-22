%% The FFI seam, Erlang lowering — co-located with Runtime.purs exactly like
%% Runtime.js / Runtime.go / Runtime.jl. The purerl twist that the other runtimes
%% don't have: the MODULE is named `<lowered-module>@foreign`, NOT the filename.
%% purs-backend-erl finds this file next to Runtime.purs and emits it into
%% output-erl/ as `runtime@foreign.erl`.
%%
%% That @foreign-vs-filename split is the crux of the erlang FFI build recipe: a
%% generic Erlang build tool (rebar3) that treats a source tree's .erl as app
%% modules will REJECT these (module name /= file name). The recipe therefore
%% divides labour — rebar3 is deps-only, purs-backend-erl + erlc own the app. See
%% docs/ERLANG-COLUMN.md; the lesson came from purerl-tidal's src/Tidal/*.erl.
-module('runtime@foreign').
-export([runtimeName/0]).

%% PureScript String is an Erlang UTF-8 binary under purerl.
runtimeName() -> <<"Erlang (BEAM)"/utf8>>.
