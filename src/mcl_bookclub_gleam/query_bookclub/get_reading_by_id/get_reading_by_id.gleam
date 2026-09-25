//// get_reading_by_id: the reading, by its stream id. Typed like the club
//// desk; finished_at is Option(Int) because SQL NULL arrives as the atom
//// `undefined'.

import gleam/dict
import gleam/dynamic
import gleam/list
import gleam/option
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/payload.{type Payload, atom, wrap}
import mcl_bookclub_gleam/query_bookclub/bookclub_query_store

pub type Reading {
  Reading(
    reading_id: String,
    member_id: String,
    book_id: String,
    status: String,
    started_at: Int,
    pages_read: Int,
    finished_at: option.Option(Int),
  )
}

/// One reading, or not_found. The row's cells arrive in SELECT order.
pub fn find(reading_id: String) -> Result(Reading, dynamic.Dynamic) {
  case
    bookclub_query_store.q(
      "SELECT reading_id, member_id, book_id, status, started_at, pages_read, finished_at"
        <> " FROM readings WHERE reading_id = ?",
      [dynamic.string(reading_id)],
    )
  {
    Ok([
      [reading_id, member_id, book_id, status, started_at, pages, finished_at],
      ..
    ]) ->
      Ok(Reading(
        reading_id: desk.cell_string(reading_id, "reading_id"),
        member_id: desk.cell_string(member_id, "member_id"),
        book_id: desk.cell_string(book_id, "book_id"),
        status: desk.cell_string(status, "status"),
        started_at: desk.cell_int(started_at, "started_at"),
        pages_read: desk.cell_int(pages, "pages_read"),
        finished_at: desk.cell_int_option(finished_at),
      ))
    Ok([]) -> Error(atom("not_found"))
    Ok(_) -> Error(atom("not_found"))
    Error(reason) -> Error(wrap(#(atom("store_error"), reason)))
  }
}

/// The atom-keyed map form, for the admin UI's JSON replies. A reading
/// still in progress has no finished_at: the key is simply absent.
pub fn to_map(reading: Reading) -> Payload {
  let base = [
    #(atom("reading_id"), dynamic.string(reading.reading_id)),
    #(atom("member_id"), dynamic.string(reading.member_id)),
    #(atom("book_id"), dynamic.string(reading.book_id)),
    #(atom("status"), dynamic.string(reading.status)),
    #(atom("started_at"), dynamic.int(reading.started_at)),
    #(atom("pages_read"), dynamic.int(reading.pages_read)),
  ]
  case reading.finished_at {
    option.Some(at) ->
      dict.from_list(
        list.append(base, [#(atom("finished_at"), dynamic.int(at))]),
      )
    option.None -> dict.from_list(base)
  }
}
