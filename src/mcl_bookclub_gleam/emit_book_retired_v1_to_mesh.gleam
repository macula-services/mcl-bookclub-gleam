//// Emitter: each `book_retired_v1' becomes one `book_retired_v1' fact on
//// the mesh. Same deliberate choices as the member emitter: replay_policy
//// skip (never re-publish on replay) and error returns (the retry
//// machinery owns redelivery).

import gleam/dynamic
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/evoq
import mcl_bookclub_gleam/internal/mesh
import mcl_bookclub_gleam/internal/payload.{type Payload}
import mcl_bookclub_gleam/facts

pub fn interested_in() -> List(String) {
  ["book_retired_v1"]
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
  publish(facts.to_wire_payload(facts.book_retired(data)), facts.BookRetired, state)
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
