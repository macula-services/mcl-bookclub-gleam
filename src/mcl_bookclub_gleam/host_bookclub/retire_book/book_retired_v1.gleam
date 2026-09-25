//// The book_retired_v1 event: a fact about the past.
////
//// SELF-CONTAINED, like the club's archived and the member's unregistered
//// events: it echoes the bibliographic facts from the aggregate state, so
//// its projection stays an absolute, idempotent write that never depends on
//// the procured event having arrived first.

import gleam/dict
import gleam/dynamic
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/ids
import mcl_bookclub_gleam/internal/payload.{type Payload, atom}

pub type BookRetired {
  BookRetired(
    book_id: String,
    club_id: String,
    title: String,
    author: String,
    procured_at: Int,
    club_name: String,
    retired_by: String,
    retired_at: Int,
  )
}

/// The binary event type -- what evoq_event_handler's interested_in/0
/// matches on.
pub fn event_type() -> String {
  "book_retired_v1"
}

pub fn new(params: Payload) -> Result(BookRetired, dynamic.Dynamic) {
  case
    desk.get_string(params, "book_id"),
    desk.get_string(params, "club_id"),
    desk.get_string(params, "title"),
    desk.get_string(params, "author"),
    desk.get_string(params, "retired_by")
  {
    Ok(book_id), Ok(club_id), Ok(title), Ok(author), Ok(retired_by) ->
      Ok(BookRetired(
        book_id: book_id,
        club_id: club_id,
        title: title,
        author: author,
        procured_at: desk.get_int_default(params, "procured_at", 0),
        club_name: desk.get_string_default(params, "club_name", ""),
        retired_by: retired_by,
        retired_at: ids.now_ms(ids.millisecond()),
      ))
    _, _, _, _, _ -> Error(desk.missing_required_fields())
  }
}

/// The stored payload: atom keys, event_type included -- evoq extracts
/// the type with an atom lookup when it builds the envelope.
pub fn to_map(event: BookRetired) -> Payload {
  dict.from_list([
    #(atom("event_type"), dynamic.string(event_type())),
    #(atom("book_id"), dynamic.string(event.book_id)),
    #(atom("club_id"), dynamic.string(event.club_id)),
    #(atom("title"), dynamic.string(event.title)),
    #(atom("author"), dynamic.string(event.author)),
    #(atom("procured_at"), dynamic.int(event.procured_at)),
    #(atom("club_name"), dynamic.string(event.club_name)),
    #(atom("retired_by"), dynamic.string(event.retired_by)),
    #(atom("retired_at"), dynamic.int(event.retired_at)),
  ])
}

pub fn from_map(map: Payload) -> Result(BookRetired, dynamic.Dynamic) {
  case desk.get_string(map, "book_id") {
    Ok(book_id) ->
      Ok(BookRetired(
        book_id: book_id,
        club_id: desk.get_string_default(map, "club_id", ""),
        title: desk.get_string_default(map, "title", ""),
        author: desk.get_string_default(map, "author", ""),
        procured_at: desk.get_int_default(map, "procured_at", 0),
        club_name: desk.get_string_default(map, "club_name", ""),
        retired_by: desk.get_string_default(map, "retired_by", ""),
        retired_at: desk.get_int_default(map, "retired_at", 0),
      ))
    Error(e) -> Error(e)
  }
}

pub fn get_book_id(event: BookRetired) -> String {
  event.book_id
}

pub fn get_club_id(event: BookRetired) -> String {
  event.club_id
}

pub fn get_title(event: BookRetired) -> String {
  event.title
}

pub fn get_author(event: BookRetired) -> String {
  event.author
}

pub fn get_procured_at(event: BookRetired) -> Int {
  event.procured_at
}

pub fn get_retired_by(event: BookRetired) -> String {
  event.retired_by
}

pub fn get_retired_at(event: BookRetired) -> Int {
  event.retired_at
}
