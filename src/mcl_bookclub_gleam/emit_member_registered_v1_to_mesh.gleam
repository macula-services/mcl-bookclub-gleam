//// Emitter: each `member_registered_v1' becomes one
//// `member_registered_v1' fact on the mesh.
////
//// The only place this desk's event touches the mesh. The dispatch path
//// never waits for it: the fact goes out on the router's delivery, not
//// the caller's.
////
//// TWO DELIBERATE CHOICES, each worth understanding before copying:
////
//// - replay_policy/0 is `skip': a restart's replay of the store's history
////   must not re-publish facts that already went out.
////
//// - A failed publish is an ERROR RETURN, so evoq's retry machinery owns
////   redelivery: lifecycle facts (unlike telemetry) are worth retrying --
////   a consumer that missed "member registered" is missing state, not a
////   sample.

import gleam/dynamic
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/evoq
import mcl_bookclub_gleam/internal/mesh
import mcl_bookclub_gleam/internal/payload.{type Payload}
import mcl_bookclub_gleam/facts

pub fn interested_in() -> List(String) {
  ["member_registered_v1"]
}

pub fn replay_policy() -> dynamic.Dynamic {
  evoq.replay_skip()
}

pub fn init(_config: Payload) -> Result(dynamic.Dynamic, dynamic.Dynamic) {
  Ok(evoq.empty_state())
}

pub fn handle_event(
  _event_type: String,
  event: Payload,
  _metadata: Payload,
  state: dynamic.Dynamic,
) -> Result(dynamic.Dynamic, dynamic.Dynamic) {
  let data = desk.event_data(event)
  publish(
    facts.to_wire_payload(facts.member_registered(data)),
    facts.MemberRegistered,
    state,
  )
}

fn publish(
  fact: Payload,
  kind: facts.FactKind,
  state: dynamic.Dynamic,
) -> Result(dynamic.Dynamic, dynamic.Dynamic) {
  case mesh.mesh_handles() {
    Ok(#(pool, realm)) -> publish_on(pool, realm, fact, kind, state)
    Error(error) -> Error(error)
  }
}

fn publish_on(
  pool: dynamic.Dynamic,
  realm: dynamic.Dynamic,
  fact: Payload,
  kind: facts.FactKind,
  state: dynamic.Dynamic,
) -> Result(dynamic.Dynamic, dynamic.Dynamic) {
  case mesh.publish(pool, realm, facts.topic(facts.realm_name(), kind), fact) {
    Ok(_) -> Ok(state)
    Error(error) -> Error(error)
  }
}
