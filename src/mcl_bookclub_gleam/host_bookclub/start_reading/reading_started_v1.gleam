//// The reading_started_v1 event: a fact about the past.
////
//// Self-contained: it carries the member and the book being read, so any
//// downstream consumer (the projection, the mesh emitter) reads one event
//// and knows everything it needs.

import gleam/dict
import gleam/dynamic
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/ids
import mcl_bookclub_gleam/internal/payload.{atom, type Payload}

pub type ReadingStarted {
  ReadingStarted(
    reading_id: String,
    member_id: String,
    book_id: String,
    started_at: Int,
  )
}

/// The binary event type -- what evoq_event_handler's interested_in/0
/// matches on.
pub fn event_type() -> String {
  "reading_started_v1"
}

pub fn new(params: Payload) -> Result(ReadingStarted, dynamic.Dynamic) {
  case desk.get_string(params, "reading_id"),
    desk.get_string(params, "member_id"),
    desk.get_string(params, "book_id")
  {
    Ok(reading_id), Ok(member_id), Ok(book_id) ->
      Ok(ReadingStarted(
        reading_id: reading_id,
        member_id: member_id,
        book_id: book_id,
        started_at: ids.now_ms(ids.millisecond()),
      ))
    _, _, _ -> Error(desk.missing_required_fields())
  }
}

/// The stored payload: atom keys, event_type included -- evoq extracts
/// the type with an atom lookup when it builds the envelope.
pub fn to_map(event: ReadingStarted) -> Payload {
  dict.from_list([
    #(atom("event_type"), dynamic.string(event_type())),
    #(atom("reading_id"), dynamic.string(event.reading_id)),
    #(atom("member_id"), dynamic.string(event.member_id)),
    #(atom("book_id"), dynamic.string(event.book_id)),
    #(atom("started_at"), dynamic.int(event.started_at)),
  ])
}

pub fn from_map(map: Payload) -> Result(ReadingStarted, dynamic.Dynamic) {
  case desk.get_string(map, "reading_id") {
    Ok(reading_id) ->
      Ok(ReadingStarted(
        reading_id: reading_id,
        member_id: desk.get_string_default(map, "member_id", ""),
        book_id: desk.get_string_default(map, "book_id", ""),
        started_at: desk.get_int_default(map, "started_at", 0),
      ))
    Error(e) -> Error(e)
  }
}

pub fn get_reading_id(event: ReadingStarted) -> String {
  event.reading_id
}

pub fn get_member_id(event: ReadingStarted) -> String {
  event.member_id
}

pub fn get_book_id(event: ReadingStarted) -> String {
  event.book_id
}

pub fn get_started_at(event: ReadingStarted) -> Int {
  event.started_at
}
