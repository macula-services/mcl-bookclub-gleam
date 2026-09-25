//// Handler for `procure_book_v1'.
////
//// The desk: one module that owns the business rule (a book is procured
//// once), produces the matching `book_procured_v1' event, and dispatches.
//// The aggregate calls handle_from_map/2; callers dispatch/1.

import gleam/dict
import gleam/dynamic
import mcl_bookclub_gleam/host_bookclub/book_state
import mcl_bookclub_gleam/host_bookclub/procure_book/book_procured_v1
import mcl_bookclub_gleam/host_bookclub/procure_book/procure_book_v1
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/payload.{type Payload, atom}

/// The Erlang module atoms of this desk's own modules -- evoq addresses
/// the command by these.
pub const command_module = "mcl_bookclub_gleam@host_bookclub@procure_book@procure_book_v1"

pub const aggregate_module = "mcl_bookclub_gleam@host_bookclub@book_aggregate"

/// The command's payload as evoq hands it to the aggregate: the map
/// procure_book_v1:to_map/1 made, atom-keyed.
pub fn handle_from_map(
  state: book_state.BookState,
  payload: Payload,
) -> desk.DeskResult {
  case procure_book_v1.new(payload) {
    Ok(command) -> handle(state, command)
    Error(e) -> Error(e)
  }
}

/// The business rule, stated against the aggregate state: a book is
/// procured exactly once. The already-retired refusal is the aggregate's
/// blanket guard, not this desk's.
pub fn handle(
  state: book_state.BookState,
  command: procure_book_v1.ProcureBook,
) -> desk.DeskResult {
  case book_state.is_on_shelf(state) {
    True -> Error(desk.error_atom("already_procured"))
    False ->
      case procure_book_v1.validate(command) {
        Ok(_) -> events(command)
        Error(e) -> Error(e)
      }
  }
}

fn events(command: procure_book_v1.ProcureBook) -> desk.DeskResult {
  case
    book_procured_v1.new(
      dict.from_list([
        #(atom("book_id"), dynamic.string(procure_book_v1.get_book_id(command))),
        #(atom("club_id"), dynamic.string(procure_book_v1.get_club_id(command))),
        #(atom("title"), dynamic.string(procure_book_v1.get_title(command))),
        #(atom("author"), dynamic.string(procure_book_v1.get_author(command))),
        #(
          atom("club_name"),
          dynamic.string(procure_book_v1.get_club_name(command)),
        ),
      ]),
    )
  {
    Ok(event) -> Ok([book_procured_v1.to_map(event)])
    Error(e) -> Error(e)
  }
}

/// Procure the book on its own stream in the club's store. The caller
/// sees `Error(_)' rather than a success nothing stored.
///
/// VALIDATION HAPPENS HERE, BEFORE DISPATCH, AND THAT IS LOAD-BEARING:
/// the store client RAISES on a bad id, so the desk is the boundary -- it
/// validates, then dispatches (Demon 67).
pub fn dispatch(command: procure_book_v1.ProcureBook) -> desk.DispatchResult {
  case procure_book_v1.validate(command) {
    Ok(_) ->
      desk.dispatch_command(
        command_module,
        aggregate_module,
        procure_book_v1.stream_id(command),
        procure_book_v1.to_map(command),
      )
    Error(e) -> Error(e)
  }
}
