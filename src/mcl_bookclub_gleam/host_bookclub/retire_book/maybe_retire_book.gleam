//// Handler for `retire_book_v1'.
////
//// The desk: one module that owns the business rule (a book retires only
//// once it is on the shelf), produces the matching `book_retired_v1'
//// event, and dispatches. The already-retired refusal is the aggregate's
//// blanket guard, not this desk's.

import gleam/dict
import gleam/dynamic
import mcl_bookclub_gleam/host_bookclub/book_state
import mcl_bookclub_gleam/host_bookclub/retire_book/book_retired_v1
import mcl_bookclub_gleam/host_bookclub/retire_book/retire_book_v1
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/payload.{type Payload, atom}

/// The Erlang module atoms of this desk's own modules -- evoq addresses
/// the command by these.
pub const command_module = "mcl_bookclub_gleam@host_bookclub@retire_book@retire_book_v1"

pub const aggregate_module = "mcl_bookclub_gleam@host_bookclub@book_aggregate"

/// The command's payload as evoq hands it to the aggregate: the map
/// retire_book_v1:to_map/1 made, atom-keyed.
pub fn handle_from_map(
  state: book_state.BookState,
  payload: Payload,
) -> desk.DeskResult {
  case retire_book_v1.new(payload) {
    Ok(command) -> handle(state, command)
    Error(e) -> Error(e)
  }
}

/// The business rule, stated against the aggregate state: a book can
/// only retire once it is on the shelf.
pub fn handle(
  state: book_state.BookState,
  command: retire_book_v1.RetireBook,
) -> desk.DeskResult {
  case book_state.is_on_shelf(state) {
    True ->
      case retire_book_v1.validate(command) {
        Ok(_) -> events(state, command)
        Error(e) -> Error(e)
      }
    False -> Error(desk.error_atom("not_procured"))
  }
}

fn events(
  state: book_state.BookState,
  command: retire_book_v1.RetireBook,
) -> desk.DeskResult {
  case
    book_retired_v1.new(
      dict.from_list([
        #(atom("book_id"), dynamic.string(book_state.book_id(state))),
        #(atom("club_id"), dynamic.string(book_state.club_id(state))),
        #(atom("title"), dynamic.string(book_state.title(state))),
        #(atom("author"), dynamic.string(book_state.author(state))),
        #(atom("procured_at"), dynamic.int(book_state.procured_at(state))),
        #(atom("club_name"), dynamic.string(book_state.club_name(state))),
        #(
          atom("retired_by"),
          dynamic.string(retire_book_v1.get_retired_by(command)),
        ),
      ]),
    )
  {
    Ok(event) -> Ok([book_retired_v1.to_map(event)])
    Error(e) -> Error(e)
  }
}

/// Retire the book on its own stream in the club's store. The caller
/// sees `Error(_)' rather than a success nothing stored.
///
/// VALIDATION HAPPENS HERE, BEFORE DISPATCH, AND THAT IS LOAD-BEARING:
/// the store client RAISES on a bad id, so the desk is the boundary -- it
/// validates, then dispatches (Demon 67).
pub fn dispatch(command: retire_book_v1.RetireBook) -> desk.DispatchResult {
  case retire_book_v1.validate(command) {
    Ok(_) ->
      desk.dispatch_command(
        command_module,
        aggregate_module,
        retire_book_v1.stream_id(command),
        retire_book_v1.to_map(command),
      )
    Error(e) -> Error(e)
  }
}
