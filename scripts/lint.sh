#!/usr/bin/env bash
# The structural lint gate: elvis's mcl_min ruleset (no_deep_nesting level 2,
# no_nested_try_catch, no_if_expression) against the Gleam sources' generated
# Erlang -- the same mechanical rule the Erlang twin enforces on its own
# sources. gleam build regenerates the artefacts, then elvis runs DIRECTLY
# with the rebar.config's {elvis, ...} section passed as an explicit
# in-memory config.
#
# Why not `rebar3 lint`: elvis_core >= 5.0 injects `git check-ignore` output
# into every rule group's ignore list when it reads its config from a file.
# Anything under build/ is git-ignored (it must be -- it is generated), so
# the artefact glob would be silently filtered and the gate would lint
# ZERO files (which is what the first CI run caught). The direct
# {config, [...]} invocation never consults git, so it lints the artefacts
# deterministically in both dev and CI. The mcl_min ruleset definition and
# the file globs still live in rebar.config -- one config, one gate.
set -euo pipefail
cd "$(dirname "$0")/.."

run() {
  set -e
  gleam build
  exec erl -noshell -pa _build/default/plugins/*/ebin -eval '
    {ok, _} = application:ensure_all_started(elvis_core),
    {ok, Terms} = file:consult("rebar.config"),
    {elvis, ElvisConfig} = lists:keyfind(elvis, 1, Terms),
    Rulesets = proplists:get_value(rulesets, ElvisConfig, #{}),
    ok = elvis_ruleset:load_custom(Rulesets),
    RuleGroups = proplists:get_value(config, ElvisConfig, []),
    %% The canary: a gate that resolves no files passes as a no-op, and
    %% this estate has been burned by exactly that. Fail loudly instead.
    Counts =
        [length(elvis_config:files(elvis_config:resolve_files(G)))
         || G <- RuleGroups],
    case lists:all(fun(N) -> N > 0 end, Counts) of
        true ->
            ok;
        false ->
            io:format(standard_error, "lint gate resolved ~p files per group; refusing to pass on nothing~n", [Counts]),
            halt(2)
    end,
    case elvis_core:rock({config, RuleGroups}) of
        ok -> halt(0);
        {errors, _} -> halt(1);
        {warnings, _} -> halt(0)
    end.'
}

if command -v mise >/dev/null 2>&1; then
  mise x erlang@28.4.3 gleam@1.18.1 -- sh -c "$(declare -f run); run"
else
  run
fi
