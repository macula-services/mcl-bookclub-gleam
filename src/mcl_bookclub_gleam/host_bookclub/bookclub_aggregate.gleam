//// Aggregate root for a book club.
////
//// One stream per club, born by initiate_bookclub_v1 and soft-deleted by
//// archive_bookclub_v1. The aggregate is the consistency boundary: it
//// refuses a second initiation, every command once archived, and the
//// club's stream id IS its identity.
////
//// The ARCHIVED guard lives HERE, in the aggregate, because it is a
//// blanket lifecycle rule over every command the stream will ever accept.
//// Desk rules (a club initiates once, archives once) live in the desks.
//// That is the split: the aggregate owns the stream's lifecycle, the desk
//// owns the business rule.

import gleam/dynamic
import mcl_bookclub_gleam/host_bookclub/archive_bookclub/maybe_archive_bookclub
import mcl_bookclub_gleam/host_bookclub/bookclub_state
import mcl_bookclub_gleam/host_bookclub/initiate_bookclub/maybe_initiate_bookclub
import mcl_bookclub_gleam/host_bookclub/plan_party/maybe_plan_party
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/payload.{type Payload, atom}

/// The state module atom -- evoq resolves it by name.
pub fn state_module() -> dynamic.Dynamic {
  atom("mcl_bookclub_gleam@host_bookclub@bookclub_state")
}

/// evoq calls init/1 when the stream's aggregate first starts.
pub fn init(
  aggregate_id: dynamic.Dynamic,
) -> Result(bookclub_state.BookclubState, dynamic.Dynamic) {
  case desk.string_from_dynamic(aggregate_id) {
    Ok(id) -> Ok(bookclub_state.new(id))
    Error(e) -> Error(e)
  }
}

/// evoq calls execute(State, Payload) -- State FIRST. The guard rules live
/// in the desk's maybe_ module; the aggregate only dispatches on the
/// command type.
pub fn execute(
  state: bookclub_state.BookclubState,
  payload: Payload,
) -> desk.DeskResult {
  case desk.command_is(payload, "initiate_bookclub_v1") {
    True -> guarded(state, payload, maybe_initiate_bookclub.handle_from_map)
    False ->
      case desk.command_is(payload, "archive_bookclub_v1") {
        True -> guarded(state, payload, maybe_archive_bookclub.handle_from_map)
        False ->
          case desk.command_is(payload, "plan_party_v1") {
            True -> guarded(state, payload, maybe_plan_party.handle_from_map)
            False -> Error(desk.unknown_command())
          }
      }
  }
}

fn guarded(
  state: bookclub_state.BookclubState,
  payload: Payload,
  desk_fn: fn(bookclub_state.BookclubState, Payload) -> desk.DeskResult,
) -> desk.DeskResult {
  case bookclub_state.is_archived(state) {
    True -> Error(desk.error_atom("archived"))
    False -> desk_fn(state, payload)
  }
}

pub fn apply(
  state: bookclub_state.BookclubState,
  event: Payload,
) -> bookclub_state.BookclubState {
  bookclub_state.apply_event(state, event)
}

pub fn snapshot(state: bookclub_state.BookclubState) -> dynamic.Dynamic {
  desk.payload_to_dynamic(bookclub_state.to_map(state))
}

pub fn from_snapshot(
  snapshot_data: dynamic.Dynamic,
) -> bookclub_state.BookclubState {
  let assert Ok(map) = desk.decode_map(snapshot_data)
  let assert Ok(state) = bookclub_state.from_map(map)
  state
}
