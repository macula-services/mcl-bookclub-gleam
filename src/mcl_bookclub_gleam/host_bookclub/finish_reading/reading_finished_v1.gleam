//// The reading_finished_v1 event: a fact about the past.
////
//// SELF-CONTAINED, like every soft-delete event here: it echoes the member,
//// the book and the start time from the aggregate state, so its projection
//// can fold the readings row from this event alone -- an absolute,
//// idempotent write that never depends on the started event having arrived
//// first.

import gleam/dict
import gleam/dynamic
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/mesh
import mcl_bookclub_gleam/internal/payload.{atom, type Payload}

pub type ReadingFinished {
  ReadingFinished(
    reading_id: String,
    member_id: String,
    book_id: String,
    started_at: Int,
    pages_read: Int,
    finished_at: Int,
  )
}

/// The binary event type -- what evoq_event_handler's interested_in/0
/// matches on.
pub fn event_type() -> String {
  "reading_finished_v1"
}

pub fn new(params: Payload) -> Result(ReadingFinished, dynamic.Dynamic) {
  case desk.get_string(params, "reading_id"),
    desk.get_string(params, "member_id"),
    desk.get_string(params, "book_id")
  {
    Ok(reading_id), Ok(member_id), Ok(book_id) ->
      Ok(ReadingFinished(
        reading_id: reading_id,
        member_id: member_id,
        book_id: book_id,
        started_at: desk.get_int_default(params, "started_at", 0),
        pages_read: desk.get_int_default(params, "pages_read", 0),
        finished_at: mesh.now_ms(mesh.millisecond()),
      ))
    _, _, _ -> Error(desk.missing_required_fields())
  }
}

/// The stored payload: atom keys, event_type included -- evoq extracts
/// the type with an atom lookup when it builds the envelope.
pub fn to_map(event: ReadingFinished) -> Payload {
  dict.from_list([
    #(atom("event_type"), dynamic.string(event_type())),
    #(atom("reading_id"), dynamic.string(event.reading_id)),
    #(atom("member_id"), dynamic.string(event.member_id)),
    #(atom("book_id"), dynamic.string(event.book_id)),
    #(atom("started_at"), dynamic.int(event.started_at)),
    #(atom("pages_read"), dynamic.int(event.pages_read)),
    #(atom("finished_at"), dynamic.int(event.finished_at)),
  ])
}

pub fn from_map(map: Payload) -> Result(ReadingFinished, dynamic.Dynamic) {
  case desk.get_string(map, "reading_id") {
    Ok(reading_id) ->
      Ok(ReadingFinished(
        reading_id: reading_id,
        member_id: desk.get_string_default(map, "member_id", ""),
        book_id: desk.get_string_default(map, "book_id", ""),
        started_at: desk.get_int_default(map, "started_at", 0),
        pages_read: desk.get_int_default(map, "pages_read", 0),
        finished_at: desk.get_int_default(map, "finished_at", 0),
      ))
    Error(e) -> Error(e)
  }
}

pub fn get_reading_id(event: ReadingFinished) -> String {
  event.reading_id
}

pub fn get_member_id(event: ReadingFinished) -> String {
  event.member_id
}

pub fn get_book_id(event: ReadingFinished) -> String {
  event.book_id
}

pub fn get_started_at(event: ReadingFinished) -> Int {
  event.started_at
}

pub fn get_pages_read(event: ReadingFinished) -> Int {
  event.pages_read
}

pub fn get_finished_at(event: ReadingFinished) -> Int {
  event.finished_at
}
