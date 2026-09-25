#!/usr/bin/env bash
# The test gates for mcl-bookclub-gleam.
#
# `gleam test` alone cannot pass a sys.config to erl, and the test VM must
# load config/test.sys.config (macula's pq_hybrid crypto profile) before the
# generated test main starts the application tree -- mcl_om pulls macula in,
# and macula 12 refuses to start without a crypto profile. This mirrors the
# Erlang twin's `rebar3 eunit` test profile and runs the SAME generated test
# main `gleam test` would.
#
# Locally the toolchain is scoped with mise (OTP 28.4.3, gleam 1.18.1 -- the
# ambient shell is OTP 29). In CI the pinned macula-ci-gleam image ALREADY
# carries that exact toolchain, and mise is deliberately absent, so the same
# commands run unscoped.
set -euo pipefail
cd "$(dirname "$0")/.."

run() {
  set -e
  gleam build
  exec erl -noshell -config config/test.sys.config \
      -pa build/dev/erlang/*/ebin \
      -eval "mcl_bookclub_gleam@@main:run('mcl_bookclub_gleam_test')."
}

if command -v mise >/dev/null 2>&1; then
  mise x erlang@28.4.3 gleam@1.18.1 -- sh -c "$(declare -f run); run"
else
  run
fi
