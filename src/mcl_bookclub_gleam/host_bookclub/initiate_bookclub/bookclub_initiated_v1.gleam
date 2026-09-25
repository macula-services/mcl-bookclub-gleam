//// The bookclub_initiated_v1 event: a fact about the past.
////
//// Past tense, business verb, `_v1' suffix -- the house event-naming
//// rules. The module returns a binary from event_type/0, which is what
//// evoq_event_handler's interested_in/0 matches on.

import gleam/dict
import gleam/dynamic
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/ids
import mcl_bookclub_gleam/internal/payload.{type Payload, atom}

pub type BookclubInitiated {
  BookclubInitiated(
    club_id: String,
    name: String,
    initiated_by: String,
    initiated_at: Int,
  )
}

/// The binary event type -- what evoq_event_handler's interested_in/0
/// matches on.
pub fn event_type() -> String {
  "bookclub_initiated_v1"
}

pub fn new(params: Payload) -> Result(BookclubInitiated, dynamic.Dynamic) {
  case
    desk.get_string(params, "club_id"),
    desk.get_string(params, "name"),
    desk.get_string(params, "initiated_by")
  {
    Ok(club_id), Ok(name), Ok(initiated_by) ->
      Ok(BookclubInitiated(
        club_id: club_id,
        name: name,
        initiated_by: initiated_by,
        initiated_at: ids.now_ms(ids.millisecond()),
      ))
    _, _, _ -> Error(desk.missing_required_fields())
  }
}

/// The stored payload: atom keys, event_type included -- evoq extracts the
/// type with an atom lookup when it builds the envelope.
pub fn to_map(event: BookclubInitiated) -> Payload {
  dict.from_list([
    #(atom("event_type"), dynamic.string(event_type())),
    #(atom("club_id"), dynamic.string(event.club_id)),
    #(atom("name"), dynamic.string(event.name)),
    #(atom("initiated_by"), dynamic.string(event.initiated_by)),
    #(atom("initiated_at"), dynamic.int(event.initiated_at)),
  ])
}

pub fn from_map(map: Payload) -> Result(BookclubInitiated, dynamic.Dynamic) {
  case desk.get_string(map, "club_id") {
    Ok(club_id) ->
      Ok(BookclubInitiated(
        club_id: club_id,
        name: desk.get_string_default(map, "name", ""),
        initiated_by: desk.get_string_default(map, "initiated_by", ""),
        initiated_at: desk.get_int_default(map, "initiated_at", 0),
      ))
    Error(e) -> Error(e)
  }
}

pub fn get_club_id(event: BookclubInitiated) -> String {
  event.club_id
}

pub fn get_name(event: BookclubInitiated) -> String {
  event.name
}

pub fn get_initiated_by(event: BookclubInitiated) -> String {
  event.initiated_by
}

pub fn get_initiated_at(event: BookclubInitiated) -> Int {
  event.initiated_at
}
