//// Handler for `finish_reading_v1'.
////
//// The desk: one module that owns the business rule (a reading finishes
//// only once it is in progress), produces the matching `reading_finished_v1'
//// event, and dispatches. The aggregate calls handle_from_map/2; callers
//// dispatch/1. The already-finished refusal is the aggregate's blanket
//// guard, not this desk's.

import gleam/dict
import gleam/dynamic
import mcl_bookclub_gleam/host_bookclub/finish_reading/finish_reading_v1
import mcl_bookclub_gleam/host_bookclub/finish_reading/reading_finished_v1
import mcl_bookclub_gleam/host_bookclub/reading_state
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/payload.{type Payload, atom}

/// The Erlang module atoms of this desk's own modules -- evoq addresses
/// the command by these.
pub const command_module = "mcl_bookclub_gleam@host_bookclub@finish_reading@finish_reading_v1"

pub const aggregate_module = "mcl_bookclub_gleam@host_bookclub@reading_aggregate"

/// The command's payload as evoq hands it to the aggregate: the map
/// finish_reading_v1:to_map/1 made, atom-keyed.
pub fn handle_from_map(
  state: reading_state.ReadingState,
  payload: Payload,
) -> desk.DeskResult {
  case finish_reading_v1.new(payload) {
    Ok(command) -> handle(state, command)
    Error(e) -> Error(e)
  }
}

/// The business rule, stated against the aggregate state: a reading can
/// only finish once it is in progress.
pub fn handle(
  state: reading_state.ReadingState,
  command: finish_reading_v1.FinishReading,
) -> desk.DeskResult {
  case reading_state.is_in_progress(state) {
    False -> Error(desk.error_atom("not_started"))
    True ->
      case finish_reading_v1.validate(command) {
        Ok(_) -> events(state, command)
        Error(e) -> Error(e)
      }
  }
}

/// The finished event echoes the reading's birth details (member, book,
/// start time) from the aggregate state -- self-contained for its
/// projection -- and takes the pages read from the command.
fn events(
  state: reading_state.ReadingState,
  command: finish_reading_v1.FinishReading,
) -> desk.DeskResult {
  case
    reading_finished_v1.new(
      dict.from_list([
        #(atom("reading_id"), dynamic.string(reading_state.reading_id(state))),
        #(atom("member_id"), dynamic.string(reading_state.member_id(state))),
        #(atom("book_id"), dynamic.string(reading_state.book_id(state))),
        #(atom("started_at"), dynamic.int(reading_state.started_at(state))),
        #(
          atom("pages_read"),
          dynamic.int(finish_reading_v1.get_pages_read(command)),
        ),
      ]),
    )
  {
    Ok(event) -> Ok([reading_finished_v1.to_map(event)])
    Error(e) -> Error(e)
  }
}

/// Finish the reading on its own stream in the club's store. The caller
/// sees `Error(_)' rather than a success nothing stored.
///
/// VALIDATION HAPPENS HERE, BEFORE DISPATCH, AND THAT IS LOAD-BEARING:
/// the store client RAISES on a bad id, so the desk is the boundary -- it
/// validates, then dispatches (Demon 67).
pub fn dispatch(
  command: finish_reading_v1.FinishReading,
) -> desk.DispatchResult {
  case finish_reading_v1.validate(command) {
    Ok(_) ->
      desk.dispatch_command(
        command_module,
        aggregate_module,
        finish_reading_v1.stream_id(command),
        finish_reading_v1.to_map(command),
      )
    Error(e) -> Error(e)
  }
}
