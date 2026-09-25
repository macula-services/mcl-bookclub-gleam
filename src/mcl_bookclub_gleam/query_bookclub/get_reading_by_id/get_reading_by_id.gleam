//// get_reading_by_id: the reading, by its stream id.

import gleam/dict
import gleam/dynamic
import mcl_bookclub_gleam/internal/payload.{atom, type Payload, wrap}
import mcl_bookclub_gleam/query_bookclub/bookclub_query_store

/// One reading, or not_found. The row's cells arrive in SELECT order.
pub fn find(reading_id: String) -> Result(Payload, dynamic.Dynamic) {
  found(bookclub_query_store.q(
    "SELECT reading_id, member_id, book_id, status, started_at, pages_read, finished_at"
    <> " FROM readings WHERE reading_id = ?",
    [dynamic.string(reading_id)],
  ))
}

fn found(result: Result(List(List(dynamic.Dynamic)), dynamic.Dynamic)) {
  case result {
    Ok([[reading_id, member_id, book_id, status, started_at, pages, finished_at], ..]) -> Ok(dict.from_list([
      #(atom("reading_id"), reading_id),
      #(atom("member_id"), member_id),
      #(atom("book_id"), book_id),
      #(atom("status"), status),
      #(atom("started_at"), started_at),
      #(atom("pages_read"), pages),
      #(atom("finished_at"), finished_at),
    ]))
    Ok([]) -> Error(atom("not_found"))
    Ok(_) -> Error(atom("not_found"))
    Error(reason) -> Error(wrap(#(atom("store_error"), reason)))
  }
}
