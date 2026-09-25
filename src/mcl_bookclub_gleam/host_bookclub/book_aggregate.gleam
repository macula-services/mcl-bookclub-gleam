//// Aggregate root for a book on the club's shelf.
////
//// One stream per book, born by procure_book_v1 and soft-deleted by
//// retire_book_v1. Like the club and the member, the aggregate owns a
//// blanket lifecycle guard: every command on a retired stream is refused
//// before any desk sees it.

import gleam/dynamic
import mcl_bookclub_gleam/host_bookclub/book_state
import mcl_bookclub_gleam/host_bookclub/procure_book/maybe_procure_book
import mcl_bookclub_gleam/host_bookclub/retire_book/maybe_retire_book
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/payload.{type Payload, atom}

/// The state module atom -- evoq resolves it by name.
pub fn state_module() -> dynamic.Dynamic {
  atom("mcl_bookclub_gleam@host_bookclub@book_state")
}

/// evoq calls init/1 when the stream's aggregate first starts.
pub fn init(
  aggregate_id: dynamic.Dynamic,
) -> Result(book_state.BookState, dynamic.Dynamic) {
  case desk.string_from_dynamic(aggregate_id) {
    Ok(id) -> Ok(book_state.new(id))
    Error(e) -> Error(e)
  }
}

/// evoq calls execute(State, Payload) -- State FIRST. The guard rules live
/// in the desk's maybe_ module; the aggregate owns the stream's lifecycle.
pub fn execute(
  state: book_state.BookState,
  payload: Payload,
) -> desk.DeskResult {
  case desk.command_is(payload, "procure_book_v1") {
    True -> guarded(state, payload, maybe_procure_book.handle_from_map)
    False ->
      case desk.command_is(payload, "retire_book_v1") {
        True -> guarded(state, payload, maybe_retire_book.handle_from_map)
        False -> Error(desk.unknown_command())
      }
  }
}

fn guarded(
  state: book_state.BookState,
  payload: Payload,
  desk_fn: fn(book_state.BookState, Payload) -> desk.DeskResult,
) -> desk.DeskResult {
  case book_state.is_retired(state) {
    True -> Error(desk.error_atom("retired"))
    False -> desk_fn(state, payload)
  }
}

pub fn apply(
  state: book_state.BookState,
  event: Payload,
) -> book_state.BookState {
  book_state.apply_event(state, event)
}

pub fn snapshot(state: book_state.BookState) -> dynamic.Dynamic {
  desk.payload_to_dynamic(book_state.to_map(state))
}

pub fn from_snapshot(snapshot_data: dynamic.Dynamic) -> book_state.BookState {
  let assert Ok(map) = desk.decode_map(snapshot_data)
  let assert Ok(state) = book_state.from_map(map)
  state
}
