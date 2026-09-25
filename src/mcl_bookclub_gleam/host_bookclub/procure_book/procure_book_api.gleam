//// procure_book_api: the HTTP entry point for procure_book_v1.
////
//// Pure, like every entry point here -- no cowboy, no mesh. The book id
//// is minted when the operator does not bring one; the event echoes it
//// back.

import gleam/dict
import gleam/dynamic
import mcl_bookclub_gleam/host_bookclub/procure_book/maybe_procure_book
import mcl_bookclub_gleam/host_bookclub/procure_book/procure_book_v1
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/payload.{type Payload, atom}

/// Params arrive atom-keyed (the facade JSON-decodes with atom labels). A
/// missing book_id is minted; the event echoes it back.
pub fn handle(params: Payload) -> desk.DispatchResult {
  let book_id = case desk.get_string(params, "book_id") {
    Ok("") -> procure_book_v1.mint_book_id()
    Ok(id) -> id
    Error(_) -> procure_book_v1.mint_book_id()
  }
  let params = dict.insert(params, atom("book_id"), dynamic.string(book_id))
  case procure_book_v1.new(params) {
    Ok(command) -> maybe_procure_book.dispatch(command)
    Error(e) -> Error(e)
  }
}
