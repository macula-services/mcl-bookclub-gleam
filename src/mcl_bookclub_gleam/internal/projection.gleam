//// The shared projection shape: every PRJ desk is an evoq_event_handler
//// with these four exports. A projection's write is idempotent by
//// construction (INSERT OR REPLACE, the row carrying event_id + version),
//// so it declares `deliver' and replays safely.

import gleam/dynamic
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/evoq
import mcl_bookclub_gleam/internal/payload.{type Payload, atom, wrap}

/// The handler's interest: the event types it projects.
pub fn interested_in(types: List(String)) -> List(String) {
  types
}

/// Idempotent consumers re-apply and stay complete.
pub fn replay_policy() -> dynamic.Dynamic {
  evoq.replay_deliver()
}

/// The handler state: an empty map, like the twins' #{}.
pub fn init(_config: Payload) -> Result(dynamic.Dynamic, dynamic.Dynamic) {
  Ok(evoq.empty_state())
}

/// A store error is a retryable condition, never a crash: evoq's retry
/// machinery owns the redelivery.
pub fn store_error(reason: dynamic.Dynamic) -> dynamic.Dynamic {
  wrap(#(atom("store_error"), reason))
}

/// The stored envelope's business fields.
pub fn data_of(event: Payload) -> Payload {
  desk.event_data(event)
}

/// The row's event_id, from the envelope (atom or binary key).
pub fn event_id_of(event: Payload) -> String {
  desk.get_string_default(event, "event_id", "")
}

/// The row's version, from the envelope.
pub fn version_of(event: Payload) -> Int {
  desk.get_int_default(event, "version", 0)
}
