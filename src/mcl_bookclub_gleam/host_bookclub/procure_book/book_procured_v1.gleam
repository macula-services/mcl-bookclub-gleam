//// The book_procured_v1 event: a fact about the past.
////
//// Self-contained: it carries the club and the bibliographic facts, so any
//// downstream consumer reads one event and knows everything it needs.

import gleam/dict
import gleam/dynamic
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/ids
import mcl_bookclub_gleam/internal/payload.{atom, type Payload}

pub type BookProcured {
  BookProcured(
    book_id: String,
    club_id: String,
    title: String,
    author: String,
    club_name: String,
    procured_at: Int,
  )
}

/// The binary event type -- what evoq_event_handler's interested_in/0
/// matches on.
pub fn event_type() -> String {
  "book_procured_v1"
}

pub fn new(params: Payload) -> Result(BookProcured, dynamic.Dynamic) {
  case desk.get_string(params, "book_id"),
    desk.get_string(params, "club_id"),
    desk.get_string(params, "title"),
    desk.get_string(params, "author")
  {
    Ok(book_id), Ok(club_id), Ok(title), Ok(author) ->
      Ok(BookProcured(
        book_id: book_id,
        club_id: club_id,
        title: title,
        author: author,
        club_name: desk.get_string_default(params, "club_name", ""),
        procured_at: ids.now_ms(ids.millisecond()),
      ))
    _, _, _, _ -> Error(desk.missing_required_fields())
  }
}

/// The stored payload: atom keys, event_type included -- evoq extracts
/// the type with an atom lookup when it builds the envelope.
pub fn to_map(event: BookProcured) -> Payload {
  dict.from_list([
    #(atom("event_type"), dynamic.string(event_type())),
    #(atom("book_id"), dynamic.string(event.book_id)),
    #(atom("club_id"), dynamic.string(event.club_id)),
    #(atom("title"), dynamic.string(event.title)),
    #(atom("author"), dynamic.string(event.author)),
    #(atom("club_name"), dynamic.string(event.club_name)),
    #(atom("procured_at"), dynamic.int(event.procured_at)),
  ])
}

pub fn from_map(map: Payload) -> Result(BookProcured, dynamic.Dynamic) {
  case desk.get_string(map, "book_id") {
    Ok(book_id) ->
      Ok(BookProcured(
        book_id: book_id,
        club_id: desk.get_string_default(map, "club_id", ""),
        title: desk.get_string_default(map, "title", ""),
        author: desk.get_string_default(map, "author", ""),
        club_name: desk.get_string_default(map, "club_name", ""),
        procured_at: desk.get_int_default(map, "procured_at", 0),
      ))
    Error(e) -> Error(e)
  }
}

pub fn get_book_id(event: BookProcured) -> String {
  event.book_id
}

pub fn get_club_id(event: BookProcured) -> String {
  event.club_id
}

pub fn get_title(event: BookProcured) -> String {
  event.title
}

pub fn get_author(event: BookProcured) -> String {
  event.author
}

pub fn get_procured_at(event: BookProcured) -> Int {
  event.procured_at
}
