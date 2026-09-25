//// get_readings_by_member: every reading a member has, oldest first.

import gleam/dict
import gleam/dynamic
import gleam/list
import mcl_bookclub_gleam/internal/payload.{type Payload, atom, wrap}
import mcl_bookclub_gleam/query_bookclub/bookclub_query_store

/// All of a member's readings, or not_found. The rows' cells arrive in
/// SELECT order.
pub fn find(member_id: String) -> Result(List(Payload), dynamic.Dynamic) {
  case
    bookclub_query_store.q(
      "SELECT reading_id, member_id, book_id, status, started_at, pages_read, finished_at"
        <> " FROM readings WHERE member_id = ? ORDER BY started_at",
      [dynamic.string(member_id)],
    )
  {
    Ok(rows) -> Ok(list.map(rows, to_map))
    Error(reason) -> Error(wrap(#(atom("store_error"), reason)))
  }
}

fn to_map(row: List(dynamic.Dynamic)) -> Payload {
  case row {
    [reading_id, member_id, book_id, status, started_at, pages, finished_at] ->
      dict.from_list([
        #(atom("reading_id"), reading_id),
        #(atom("member_id"), member_id),
        #(atom("book_id"), book_id),
        #(atom("status"), status),
        #(atom("started_at"), started_at),
        #(atom("pages_read"), pages),
        #(atom("finished_at"), finished_at),
      ])
    _ -> dict.new()
  }
}
