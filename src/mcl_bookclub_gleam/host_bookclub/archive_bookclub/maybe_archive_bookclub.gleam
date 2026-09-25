//// Handler for `archive_bookclub_v1'.
////
//// The desk: one module that owns the business rule (a club archives once,
//// and only after it exists), produces the matching `bookclub_archived_v1'
//// event, and dispatches. The aggregate calls handle_from_map/2; callers
//// dispatch/1.
////
//// The event echoes the club's birth details from the aggregate state, so
//// the projection stays a self-sufficient absolute write -- see
//// bookclub_archived_v1's moduledoc for why that matters.

import gleam/dict
import gleam/dynamic
import mcl_bookclub_gleam/host_bookclub/archive_bookclub/archive_bookclub_v1
import mcl_bookclub_gleam/host_bookclub/archive_bookclub/bookclub_archived_v1
import mcl_bookclub_gleam/host_bookclub/bookclub_state
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/payload.{type Payload, atom}

/// The Erlang module atoms of this desk's own modules -- evoq addresses
/// the command by these.
pub const command_module = "mcl_bookclub_gleam@host_bookclub@archive_bookclub@archive_bookclub_v1"

pub const aggregate_module = "mcl_bookclub_gleam@host_bookclub@bookclub_aggregate"

/// The command's payload as evoq hands it to the aggregate: the map
/// archive_bookclub_v1:to_map/1 made, atom-keyed.
pub fn handle_from_map(
  state: bookclub_state.BookclubState,
  payload: Payload,
) -> desk.DeskResult {
  case archive_bookclub_v1.new(payload) {
    Ok(command) -> handle(state, command)
    Error(e) -> Error(e)
  }
}

/// The business rule, stated against the aggregate state: a club can only
/// be archived once it exists. The already-archived refusal is NOT here:
/// the aggregate's blanket lifecycle guard owns it and returns
/// `{error, archived}' for every command on an archived stream before any
/// desk sees it, so a check here would be dead code.
pub fn handle(
  state: bookclub_state.BookclubState,
  command: archive_bookclub_v1.ArchiveBookclub,
) -> desk.DeskResult {
  case
    bookclub_state.is_initiated(state),
    archive_bookclub_v1.validate(command)
  {
    False, _ -> Error(desk.error_atom("not_initiated"))
    True, Ok(_) -> events(state, command)
    True, Error(e) -> Error(e)
  }
}

/// The event echoes the club's birth details from the aggregate state, so
/// the projection stays a self-sufficient absolute write.
fn events(
  state: bookclub_state.BookclubState,
  command: archive_bookclub_v1.ArchiveBookclub,
) -> desk.DeskResult {
  case
    bookclub_archived_v1.new(
      dict.from_list([
        #(atom("club_id"), dynamic.string(bookclub_state.club_id(state))),
        #(atom("name"), dynamic.string(bookclub_state.name(state))),
        #(
          atom("initiated_by"),
          dynamic.string(bookclub_state.initiated_by(state)),
        ),
        #(atom("initiated_at"), dynamic.int(bookclub_state.initiated_at(state))),
        #(
          atom("archived_by"),
          dynamic.string(archive_bookclub_v1.get_archived_by(command)),
        ),
      ]),
    )
  {
    Ok(event) -> Ok([bookclub_archived_v1.to_map(event)])
    Error(e) -> Error(e)
  }
}

/// Archive the club on its own stream in the club's store. The caller sees
/// `Error(_)' rather than a success nothing stored.
///
/// VALIDATION HAPPENS HERE, BEFORE DISPATCH, AND THAT IS LOAD-BEARING:
/// the store client RAISES on a bad id, so the desk is the boundary -- it
/// validates, then dispatches (Demon 67).
pub fn dispatch(
  command: archive_bookclub_v1.ArchiveBookclub,
) -> desk.DispatchResult {
  case archive_bookclub_v1.validate(command) {
    Ok(_) ->
      desk.dispatch_command(
        command_module,
        aggregate_module,
        archive_bookclub_v1.stream_id(command),
        archive_bookclub_v1.to_map(command),
      )
    Error(e) -> Error(e)
  }
}
