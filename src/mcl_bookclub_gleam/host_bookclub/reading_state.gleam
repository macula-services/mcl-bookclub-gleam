//// The reading aggregate's state: the record, its fold, its shape.
////
//// The state module is the only module that sees the record. It remembers
//// the birth details (member_id, book_id, started_at), so the finished
//// event can echo them and stay self-contained for its projection -- the
//// fold a consumer needs, carried by the event instead of re-read from
//// the stream.

import gleam/dict
import gleam/dynamic
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/evoq
import mcl_bookclub_gleam/internal/payload.{atom, type Payload}
import mcl_bookclub_gleam/host_bookclub/reading_status

pub type ReadingState {
  ReadingState(
    reading_id: String,
    member_id: String,
    book_id: String,
    started_at: Int,
    pages_read: Int,
    status: Int,
  )
}

pub fn new(reading_id: String) -> ReadingState {
  ReadingState(
    reading_id: reading_id,
    member_id: "",
    book_id: "",
    started_at: 0,
    pages_read: 0,
    status: 0,
  )
}

/// Fold one event. Read tolerantly: the raw event has its business fields
/// inline, the stored envelope has them under `data'.
pub fn apply_event(state: ReadingState, event: Payload) -> ReadingState {
  case desk.event_type_of(event) {
    "reading_started_v1" -> {
      let data = desk.event_data(event)
      ReadingState(
        ..state,
        member_id: desk.get_string_default(data, "member_id", ""),
        book_id: desk.get_string_default(data, "book_id", ""),
        started_at: desk.get_int_default(data, "started_at", 0),
        status: evoq.bit_set(state.status, reading_status.in_progress()),
      )
    }
    "reading_finished_v1" -> {
      let data = desk.event_data(event)
      ReadingState(
        ..state,
        pages_read: desk.get_int_default(data, "pages_read", 0),
        status: evoq.bit_set(state.status, reading_status.finished()),
      )
    }
    _ -> state
  }
}

pub fn to_map(state: ReadingState) -> Payload {
  dict.from_list([
    #(atom("reading_id"), dynamic.string(state.reading_id)),
    #(atom("member_id"), dynamic.string(state.member_id)),
    #(atom("book_id"), dynamic.string(state.book_id)),
    #(atom("started_at"), dynamic.int(state.started_at)),
    #(atom("pages_read"), dynamic.int(state.pages_read)),
    #(atom("status"), dynamic.int(state.status)),
  ])
}

pub fn from_map(map: Payload) -> Result(ReadingState, dynamic.Dynamic) {
  case desk.get_string(map, "reading_id") {
    Ok(reading_id) ->
      Ok(ReadingState(
        reading_id: reading_id,
        member_id: desk.get_string_default(map, "member_id", ""),
        book_id: desk.get_string_default(map, "book_id", ""),
        started_at: desk.get_int_default(map, "started_at", 0),
        pages_read: desk.get_int_default(map, "pages_read", 0),
        status: desk.get_int_default(map, "status", 0),
      ))
    Error(e) -> Error(e)
  }
}

pub fn reading_id(state: ReadingState) -> String {
  state.reading_id
}

pub fn member_id(state: ReadingState) -> String {
  state.member_id
}

pub fn book_id(state: ReadingState) -> String {
  state.book_id
}

pub fn started_at(state: ReadingState) -> Int {
  state.started_at
}

pub fn pages_read(state: ReadingState) -> Int {
  state.pages_read
}

pub fn is_in_progress(state: ReadingState) -> Bool {
  evoq.bit_has(state.status, reading_status.in_progress())
}

pub fn is_finished(state: ReadingState) -> Bool {
  evoq.bit_has(state.status, reading_status.finished())
}
