//// Aggregate root for one member's reading of one book.
////
//// One stream per reading, born by start_reading_v1 and closed by
//// finish_reading_v1. The reading is the child: the member identifies it
//// (mints the reading id), the reading initiates itself with its own
//// birth event. Like every aggregate here, it owns a blanket lifecycle
//// guard: every command on a finished stream is refused before any desk
//// sees it.

import gleam/dynamic
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/payload.{atom, type Payload}
import mcl_bookclub_gleam/host_bookclub/reading_state
import mcl_bookclub_gleam/host_bookclub/finish_reading/maybe_finish_reading
import mcl_bookclub_gleam/host_bookclub/start_reading/maybe_start_reading

/// The state module atom -- evoq resolves it by name.
pub fn state_module() -> dynamic.Dynamic {
  atom("mcl_bookclub_gleam@host_bookclub@reading_state")
}

/// evoq calls init/1 when the stream's aggregate first starts.
pub fn init(aggregate_id: dynamic.Dynamic) -> Result(reading_state.ReadingState, dynamic.Dynamic) {
  case desk.string_from_dynamic(aggregate_id) {
    Ok(id) -> Ok(reading_state.new(id))
    Error(e) -> Error(e)
  }
}

/// evoq calls execute(State, Payload) -- State FIRST. The guard rules live
/// in the desk's maybe_ module; the aggregate owns the stream's lifecycle.
pub fn execute(state: reading_state.ReadingState, payload: Payload) -> desk.DeskResult {
  case desk.command_is(payload, "start_reading_v1") {
    True -> guarded(state, payload, maybe_start_reading.handle_from_map)
    False ->
      case desk.command_is(payload, "finish_reading_v1") {
        True -> guarded(state, payload, maybe_finish_reading.handle_from_map)
        False -> Error(desk.unknown_command())
      }
  }
}

fn guarded(
  state: reading_state.ReadingState,
  payload: Payload,
  desk_fn: fn(reading_state.ReadingState, Payload) -> desk.DeskResult,
) -> desk.DeskResult {
  case reading_state.is_finished(state) {
    True -> Error(desk.error_atom("finished"))
    False -> desk_fn(state, payload)
  }
}

pub fn apply(state: reading_state.ReadingState, event: Payload) -> reading_state.ReadingState {
  reading_state.apply_event(state, event)
}

pub fn snapshot(state: reading_state.ReadingState) -> dynamic.Dynamic {
  desk.payload_to_dynamic(reading_state.to_map(state))
}

pub fn from_snapshot(snapshot_data: dynamic.Dynamic) -> reading_state.ReadingState {
  let assert Ok(map) = desk.decode_map(snapshot_data)
  let assert Ok(state) = reading_state.from_map(map)
  state
}
