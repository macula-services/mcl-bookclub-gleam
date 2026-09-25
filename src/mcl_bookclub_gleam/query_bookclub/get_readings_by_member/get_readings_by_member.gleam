//// get_readings_by_member: every reading a member has, oldest first.
//// Typed like the club desk.

import gleam/dynamic
import gleam/list
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/payload.{type Payload, atom, wrap}
import mcl_bookclub_gleam/query_bookclub/bookclub_query_store
import mcl_bookclub_gleam/query_bookclub/get_reading_by_id/get_reading_by_id

/// All of a member's readings, oldest first.
pub fn find(
  member_id: String,
) -> Result(List(get_reading_by_id.Reading), dynamic.Dynamic) {
  case
    bookclub_query_store.q(
      "SELECT reading_id, member_id, book_id, status, started_at, pages_read, finished_at"
        <> " FROM readings WHERE member_id = ? ORDER BY started_at",
      [dynamic.string(member_id)],
    )
  {
    Ok(rows) -> Ok(list.map(rows, to_reading))
    Error(reason) -> Error(wrap(#(atom("store_error"), reason)))
  }
}

fn to_reading(row: List(dynamic.Dynamic)) -> get_reading_by_id.Reading {
  case row {
    [reading_id, member_id, book_id, status, started_at, pages, finished_at] ->
      get_reading_by_id.Reading(
        reading_id: desk.cell_string(reading_id, "reading_id"),
        member_id: desk.cell_string(member_id, "member_id"),
        book_id: desk.cell_string(book_id, "book_id"),
        status: desk.cell_string(status, "status"),
        started_at: desk.cell_int(started_at, "started_at"),
        pages_read: desk.cell_int(pages, "pages_read"),
        finished_at: desk.cell_int_option(finished_at),
      )
    _ -> panic as "unexpected row shape"
  }
}

/// The atom-keyed map forms, for the admin UI's JSON replies.
pub fn to_maps(readings: List(get_reading_by_id.Reading)) -> List(Payload) {
  list.map(readings, get_reading_by_id.to_map)
}
