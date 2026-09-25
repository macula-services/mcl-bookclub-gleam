#!/usr/bin/env bash
# The structural lint gate: elvis's mcl_min ruleset (no_deep_nesting level 2,
# no_nested_try_catch, no_if_expression) against the Gleam sources' generated
# Erlang -- the same mechanical rule the Erlang twin enforces on its own
# sources. gleam build regenerates the artefacts; rebar3's lint provider
# (rebar3_lint) then runs elvis over them.
set -euo pipefail
cd "$(dirname "$0")/.."

run() {
  set -e
  gleam build
  exec rebar3 lint
}

if command -v mise >/dev/null 2>&1; then
  mise x erlang@28.4.3 gleam@1.18.1 -- sh -c "$(declare -f run); run"
else
  run
fi
