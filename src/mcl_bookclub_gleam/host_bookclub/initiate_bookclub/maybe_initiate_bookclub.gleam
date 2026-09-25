//// Handler for `initiate_bookclub_v1'.
////
//// The desk: one module that owns the business rule (a club can only be
//// initiated once), produces the matching `bookclub_initiated_v1' event,
//// and dispatches. The aggregate calls handle_from_map/2; callers
//// dispatch/1. The already-initiated refusal is the desk's rule, stated
//// against the aggregate state.

import gleam/dict
import gleam/dynamic
import mcl_bookclub_gleam/host_bookclub/bookclub_state
import mcl_bookclub_gleam/host_bookclub/initiate_bookclub/bookclub_initiated_v1
import mcl_bookclub_gleam/host_bookclub/initiate_bookclub/initiate_bookclub_v1
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/payload.{type Payload, atom}

/// The Erlang module atoms of this desk's own modules -- evoq addresses
/// the command by these.
pub const command_module = "mcl_bookclub_gleam@host_bookclub@initiate_bookclub@initiate_bookclub_v1"

pub const aggregate_module = "mcl_bookclub_gleam@host_bookclub@bookclub_aggregate"

/// The command's payload as evoq hands it to the aggregate: the map
/// initiate_bookclub_v1:to_map/1 made, atom-keyed.
pub fn handle_from_map(
  state: bookclub_state.BookclubState,
  payload: Payload,
) -> desk.DeskResult {
  case initiate_bookclub_v1.new(payload) {
    Ok(command) -> handle(state, command)
    Error(e) -> Error(e)
  }
}

/// The business rule, stated against the aggregate state: a club is
/// initiated exactly once.
pub fn handle(
  state: bookclub_state.BookclubState,
  command: initiate_bookclub_v1.InitiateBookclub,
) -> desk.DeskResult {
  case
    bookclub_state.is_initiated(state),
    initiate_bookclub_v1.validate(command)
  {
    True, _ -> Error(desk.error_atom("already_initiated"))
    False, Ok(_) -> events(command)
    False, Error(e) -> Error(e)
  }
}

fn events(command: initiate_bookclub_v1.InitiateBookclub) -> desk.DeskResult {
  case
    bookclub_initiated_v1.new(
      dict.from_list([
        #(
          atom("club_id"),
          dynamic.string(initiate_bookclub_v1.get_club_id(command)),
        ),
        #(atom("name"), dynamic.string(initiate_bookclub_v1.get_name(command))),
        #(
          atom("initiated_by"),
          dynamic.string(initiate_bookclub_v1.get_initiated_by(command)),
        ),
      ]),
    )
  {
    Ok(event) -> Ok([bookclub_initiated_v1.to_map(event)])
    Error(e) -> Error(e)
  }
}

/// Initiate the club on its own stream in the club's store. The caller
/// sees `Error(_)' rather than a success nothing stored.
///
/// VALIDATION HAPPENS HERE, BEFORE DISPATCH, AND THAT IS LOAD-BEARING:
/// the store client RAISES on a bad id, so the desk is the boundary -- it
/// validates, then dispatches (Demon 67).
pub fn dispatch(
  command: initiate_bookclub_v1.InitiateBookclub,
) -> desk.DispatchResult {
  case initiate_bookclub_v1.validate(command) {
    Ok(_) ->
      desk.dispatch_command(
        command_module,
        aggregate_module,
        initiate_bookclub_v1.stream_id(command),
        initiate_bookclub_v1.to_map(command),
      )
    Error(e) -> Error(e)
  }
}
