//// get_book_by_id: the book, by its stream id.

import gleam/dict
import gleam/dynamic
import mcl_bookclub_gleam/internal/payload.{type Payload, atom, wrap}
import mcl_bookclub_gleam/query_bookclub/bookclub_query_store

/// One book, or not_found. The row's cells arrive in SELECT order.
pub fn find(book_id: String) -> Result(Payload, dynamic.Dynamic) {
  found(
    bookclub_query_store.q(
      "SELECT book_id, club_id, title, author, status, procured_at FROM books WHERE book_id = ?",
      [dynamic.string(book_id)],
    ),
  )
}

fn found(result: Result(List(List(dynamic.Dynamic)), dynamic.Dynamic)) {
  case result {
    Ok([[book_id, club_id, title, author, status, procured_at], ..]) ->
      Ok(
        dict.from_list([
          #(atom("book_id"), book_id),
          #(atom("club_id"), club_id),
          #(atom("title"), title),
          #(atom("author"), author),
          #(atom("status"), status),
          #(atom("procured_at"), procured_at),
        ]),
      )
    Ok([]) -> Error(atom("not_found"))
    Ok(_) -> Error(atom("not_found"))
    Error(reason) -> Error(wrap(#(atom("store_error"), reason)))
  }
}
