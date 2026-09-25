//// The book aggregate's state: the record, its fold, its shape.
////
//// The state module is the only module that sees the record. It remembers
//// the birth details (club_id, title, author, procured_at, club_name), so
//// the retired event can echo them and stay self-contained for its
//// projection.

import gleam/dict
import gleam/dynamic
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/evoq
import mcl_bookclub_gleam/internal/payload.{atom, type Payload}
import mcl_bookclub_gleam/host_bookclub/book_status

pub type BookState {
  BookState(
    book_id: String,
    club_id: String,
    title: String,
    author: String,
    procured_at: Int,
    club_name: String,
    status: Int,
  )
}

pub fn new(book_id: String) -> BookState {
  BookState(
    book_id: book_id,
    club_id: "",
    title: "",
    author: "",
    procured_at: 0,
    club_name: "",
    status: 0,
  )
}

/// Fold one event. Read tolerantly: the raw event has its business fields
/// inline, the stored envelope has them under `data'.
pub fn apply_event(state: BookState, event: Payload) -> BookState {
  case desk.event_type_of(event) {
    "book_procured_v1" -> {
      let data = desk.event_data(event)
      BookState(
        ..state,
        club_id: desk.get_string_default(data, "club_id", ""),
        title: desk.get_string_default(data, "title", ""),
        author: desk.get_string_default(data, "author", ""),
        procured_at: desk.get_int_default(data, "procured_at", 0),
        club_name: desk.get_string_default(data, "club_name", ""),
        status: evoq.bit_set(state.status, book_status.on_shelf()),
      )
    }
    "book_retired_v1" ->
      BookState(
        ..state,
        status: evoq.bit_set(state.status, book_status.retired()),
      )
    _ -> state
  }
}

pub fn to_map(state: BookState) -> Payload {
  dict.from_list([
    #(atom("book_id"), dynamic.string(state.book_id)),
    #(atom("club_id"), dynamic.string(state.club_id)),
    #(atom("title"), dynamic.string(state.title)),
    #(atom("author"), dynamic.string(state.author)),
    #(atom("procured_at"), dynamic.int(state.procured_at)),
    #(atom("club_name"), dynamic.string(state.club_name)),
    #(atom("status"), dynamic.int(state.status)),
  ])
}

pub fn from_map(map: Payload) -> Result(BookState, dynamic.Dynamic) {
  case desk.get_string(map, "book_id") {
    Ok(book_id) ->
      Ok(BookState(
        book_id: book_id,
        club_id: desk.get_string_default(map, "club_id", ""),
        title: desk.get_string_default(map, "title", ""),
        author: desk.get_string_default(map, "author", ""),
        procured_at: desk.get_int_default(map, "procured_at", 0),
        club_name: desk.get_string_default(map, "club_name", ""),
        status: desk.get_int_default(map, "status", 0),
      ))
    Error(e) -> Error(e)
  }
}

pub fn book_id(state: BookState) -> String {
  state.book_id
}

pub fn club_id(state: BookState) -> String {
  state.club_id
}

pub fn title(state: BookState) -> String {
  state.title
}

pub fn author(state: BookState) -> String {
  state.author
}

pub fn procured_at(state: BookState) -> Int {
  state.procured_at
}

pub fn club_name(state: BookState) -> String {
  state.club_name
}

pub fn is_on_shelf(state: BookState) -> Bool {
  evoq.bit_has(state.status, book_status.on_shelf())
}

pub fn is_retired(state: BookState) -> Bool {
  evoq.bit_has(state.status, book_status.retired())
}
