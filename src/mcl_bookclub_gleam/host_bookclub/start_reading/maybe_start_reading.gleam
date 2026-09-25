//// Handler for `start_reading_v1'.
////
//// The desk: one module that owns the business rule (a reading starts
//// once), produces the matching `reading_started_v1' event, and
//// dispatches. The aggregate calls handle_from_map/2; callers dispatch/1.
//// The already-finished refusal is the aggregate's blanket guard, not this
//// desk's.

import gleam/dict
import gleam/dynamic
import mcl_bookclub_gleam/host_bookclub/reading_state
import mcl_bookclub_gleam/host_bookclub/start_reading/reading_started_v1
import mcl_bookclub_gleam/host_bookclub/start_reading/start_reading_v1
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/payload.{type Payload, atom}

/// The Erlang module atoms of this desk's own modules -- evoq addresses
/// the command by these.
pub const command_module = "mcl_bookclub_gleam@host_bookclub@start_reading@start_reading_v1"

pub const aggregate_module = "mcl_bookclub_gleam@host_bookclub@reading_aggregate"

/// The command's payload as evoq hands it to the aggregate: the map
/// start_reading_v1:to_map/1 made, atom-keyed.
pub fn handle_from_map(
  state: reading_state.ReadingState,
  payload: Payload,
) -> desk.DeskResult {
  case start_reading_v1.new(payload) {
    Ok(command) -> handle(state, command)
    Error(e) -> Error(e)
  }
}

/// The business rule, stated against the aggregate state: a reading
/// starts exactly once. The already-finished refusal is the aggregate's
/// blanket guard, not this desk's.
pub fn handle(
  state: reading_state.ReadingState,
  command: start_reading_v1.StartReading,
) -> desk.DeskResult {
  case reading_state.is_in_progress(state), start_reading_v1.validate(command) {
    True, _ -> Error(desk.error_atom("already_started"))
    False, Ok(_) -> events(command)
    False, Error(e) -> Error(e)
  }
}

fn events(command: start_reading_v1.StartReading) -> desk.DeskResult {
  case
    reading_started_v1.new(
      dict.from_list([
        #(
          atom("reading_id"),
          dynamic.string(start_reading_v1.get_reading_id(command)),
        ),
        #(
          atom("member_id"),
          dynamic.string(start_reading_v1.get_member_id(command)),
        ),
        #(
          atom("book_id"),
          dynamic.string(start_reading_v1.get_book_id(command)),
        ),
      ]),
    )
  {
    Ok(event) -> Ok([reading_started_v1.to_map(event)])
    Error(e) -> Error(e)
  }
}

/// Start the reading on its own stream in the club's store. The caller
/// sees `Error(_)' rather than a success nothing stored.
///
/// VALIDATION HAPPENS HERE, BEFORE DISPATCH, AND THAT IS LOAD-BEARING:
/// the store client RAISES on a bad id, so the desk is the boundary -- it
/// validates, then dispatches (Demon 67).
pub fn dispatch(command: start_reading_v1.StartReading) -> desk.DispatchResult {
  case start_reading_v1.validate(command) {
    Ok(_) ->
      desk.dispatch_command(
        command_module,
        aggregate_module,
        start_reading_v1.stream_id(command),
        start_reading_v1.to_map(command),
      )
    Error(e) -> Error(e)
  }
}
