//// The OTP application entry for mcl-bookclub-gleam.
////
//// mcl_om:boot/1 wires the mesh, the realm identity, capabilities and
//// health, and -- because the service exports store_id/0 + data_dir/0 --
//// it also opens the reckon-db store and starts its evoq subscription
//// BEFORE ServiceMod:start/1 fires. That ordering is load-bearing for a
//// single-app port: the twins get it from their umbrella application
//// order (division apps start before the facade app), this app gets it by
//// starting the division supervisors HERE, before calling mcl_om:boot/1.
//// By the time the subscription's catch-up replay runs, every
//// deliver-policy projection is registered and listening.
////
//// This module is the release's application start callback (the `mod'
//// entry in the patched .app file -- see scripts/ for the release
//// assembly); `gleam test` never runs it.

import gleam/dynamic
import mcl_bookclub_gleam/internal/mesh
import mcl_bookclub_gleam/internal/payload.{atom, wrap}
import mcl_bookclub_gleam/root_supervisor

pub fn start(
  _type: dynamic.Dynamic,
  _args: dynamic.Dynamic,
) -> Result(dynamic.Dynamic, dynamic.Dynamic) {
  case root_supervisor.start() {
    Ok(_) -> mesh.boot(atom("mcl_bookclub_gleam@service"))
    Error(error) -> Error(wrap(#(atom("root_supervisor"), wrap(error))))
  }
}

pub fn stop(_state: dynamic.Dynamic) -> dynamic.Dynamic {
  atom("ok")
}
