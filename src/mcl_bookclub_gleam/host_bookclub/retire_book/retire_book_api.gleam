//// retire_book_api: the HTTP entry point for retire_book_v1.
////
//// Pure, like every entry point here. The book id is REQUIRED.

import mcl_bookclub_gleam/host_bookclub/retire_book/maybe_retire_book
import mcl_bookclub_gleam/host_bookclub/retire_book/retire_book_v1
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/payload.{type Payload}

/// Params arrive atom-keyed (the facade JSON-decodes with atom labels).
/// Both book_id and retired_by are required; a missing one refuses.
pub fn handle(params: Payload) -> desk.DispatchResult {
  case retire_book_v1.new(params) {
    Ok(command) -> maybe_retire_book.dispatch(command)
    Error(e) -> Error(e)
  }
}
