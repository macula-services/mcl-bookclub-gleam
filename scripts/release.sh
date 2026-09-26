#!/usr/bin/env bash
# Assemble the OTP release from the gleam build output.
#
# Gleam owns compilation (gleam build resolves and compiles everything,
# including the hex Erlang deps). rebar3's relx provider only ASSEMBLES the
# release from the prebuilt apps -- see rebar.config's {relx, [...]}. The
# .app files are patched in a STAGED COPY of the build tree, never in place:
# the gleam test wrapper must keep running against the unpatched .app (no mod
# entry, so the app starts as a library and the mesh is never booted in tests).
#
# Scope the toolchain exactly like the twins: OTP 28.4.3 and gleam 1.18.1.
set -euo pipefail
cd "$(dirname "$0")/.."

rm -rf build/release-libs
cp -r build/dev/erlang build/release-libs

# gleam.toml's [dev_dependencies], by name: patch_app.escript drops them from
# every .app so relx never pulls them into the release.
DEV_DEPS=$(awk '/^\[/{dev = ($0 == "[dev_dependencies]")} dev && /^[a-z_]+ *=/{print $1}' gleam.toml | paste -sd, -)
export DEV_DEPS

# The test beams, gone from the release BEFORE the .app patch: the patch
# unions every remaining beam into the modules list, and relx's embedded boot
# script preloads exactly that list -- a listed-but-deleted beam is a
# {load_failed, ...} at boot.
rm -f build/release-libs/mcl_bookclub_gleam/ebin/mcl_bookclub_gleam_test.beam
rm -f build/release-libs/mcl_bookclub_gleam/ebin/mcl_bookclub_gleam@test_support.beam
rm -f build/release-libs/mcl_bookclub_gleam/ebin/mcl_bookclub_gleam@@main.beam
find build/release-libs/mcl_bookclub_gleam/ebin -name '*_test.beam' -delete

# The releasable .app: mod entry in, the dev dependencies and the test modules out, and
# every beam in ebin unioned into the modules list. That union runs over
# EVERY staged app: relx's embedded boot script preloads only listed
# modules, and a package can ship a beam its own .app omits (gleam_otp
# 1.3.0 omits gleam_otp_external, gleam_erlang omits gleam_erlang_ffi --
# both are undef at boot otherwise).
escript scripts/patch_app.escript build/release-libs/mcl_bookclub_gleam/ebin with_mod
for app in build/release-libs/*/ebin; do
    escript scripts/patch_app.escript "$app"
done

# The admin UI's static assets: cowboy_static reads them from the app's
# priv_dir. gleam symlinks priv/ into its build output; replace the staged
# symlink with a real copy so relx carries actual files.
rm -f build/release-libs/mcl_bookclub_gleam/priv
cp -r priv build/release-libs/mcl_bookclub_gleam/

# Assemble, into a fresh output dir: relx adds to an existing release's lib/
# and never removes an app a previous assembly put there.
rm -rf _build/release
ERL_LIBS=build/dev/erlang rebar3 as prod release

# A dev dependency (gleam.toml [dev_dependencies]: the test runner, the lint
# engine) must never ship. Gleam lists them in the service's .app like any
# dependency; patch_app.escript drops them, and this refuses a release that
# still carries one.
shipped=$(for dep in ${DEV_DEPS//,/ }; do
    ls -d _build/release/mcl_bookclub_gleam/lib/"$dep"-* 2>/dev/null || true
done)
if [ -n "$shipped" ]; then
    echo "release carries dev dependencies: $shipped" >&2
    exit 1
fi
