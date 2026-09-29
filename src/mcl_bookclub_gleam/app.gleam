//// The OTP application entry for mcl-bookclub-gleam.
////
//// This app opens its own reckon-db store and starts its evoq subscription
//// (internal/store, from mcl_om 0.35 on mcl_om opens none, mcl-om#10), then
//// mcl_om:boot/1 wires the mesh, the realm identity, capabilities and
//// health. The ordering is load-bearing for a single-app port: the twins
//// get it from their umbrella application order (division apps start before
//// the facade app), this app gets it by starting the division supervisors
//// HERE, then the store, then mcl_om:boot/1.
//// By the time the subscription's catch-up replay runs, every
//// deliver-policy projection is registered and listening.
////
//// This module is the release's application start callback (the `mod'
//// entry in the patched .app file -- see scripts/ for the release
//// assembly); `gleam test` never runs it.

import gleam/dynamic
import mcl_bookclub_gleam/internal/mesh
import mcl_bookclub_gleam/internal/payload.{atom, wrap}
import mcl_bookclub_gleam/internal/store
import mcl_bookclub_gleam/root_supervisor

pub fn start(
  _type: dynamic.Dynamic,
  _args: dynamic.Dynamic,
) -> Result(dynamic.Dynamic, dynamic.Dynamic) {
  case root_supervisor.start() {
    Ok(_) -> boot_with_store()
    Error(error) -> Error(wrap(#(atom("root_supervisor"), wrap(error))))
  }
}

/// A store that cannot open stops the boot, naming why: a service whose
/// store is not there would otherwise start green and drop every command.
fn boot_with_store() -> Result(dynamic.Dynamic, dynamic.Dynamic) {
  case store.open() {
    Ok(_) -> mesh.boot(atom("mcl_bookclub_gleam@service"))
    Error(error) -> Error(wrap(#(atom("mcl_bookclub_store_failed"), error)))
  }
}

pub fn stop(_state: dynamic.Dynamic) -> dynamic.Dynamic {
  atom("ok")
}
