//// The bookclub_archived_v1 event: a fact about the past.
////
//// SELF-CONTAINED, DELIBERATELY: it echoes name, initiated_by and
//// initiated_at from the aggregate state, so its projection can rebuild
//// the whole clubs row from this event alone and stay an idempotent,
//// absolute write. The alternative -- a projection UPDATE that assumes the
//// initiated event arrived first -- breaks silently the day a projection is
//// added after history exists. The house rule: if an event is too poor for
//// its consumers, enrich it at the source.

import gleam/dict
import gleam/dynamic
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/ids
import mcl_bookclub_gleam/internal/payload.{atom, type Payload}

pub type BookclubArchived {
  BookclubArchived(
    club_id: String,
    name: String,
    initiated_by: String,
    initiated_at: Int,
    archived_by: String,
    archived_at: Int,
  )
}

/// The binary event type -- what evoq_event_handler's interested_in/0
/// matches on.
pub fn event_type() -> String {
  "bookclub_archived_v1"
}

pub fn new(params: Payload) -> Result(BookclubArchived, dynamic.Dynamic) {
  case desk.get_string(params, "club_id"),
    desk.get_string(params, "name"),
    desk.get_string(params, "initiated_by"),
    desk.get_string(params, "archived_by")
  {
    Ok(club_id), Ok(name), Ok(initiated_by), Ok(archived_by) ->
      Ok(BookclubArchived(
        club_id: club_id,
        name: name,
        initiated_by: initiated_by,
        initiated_at: desk.get_int_default(params, "initiated_at", 0),
        archived_by: archived_by,
        archived_at: ids.now_ms(ids.millisecond()),
      ))
    _, _, _, _ -> Error(desk.missing_required_fields())
  }
}

/// The stored payload: atom keys, event_type included -- evoq extracts
/// the type with an atom lookup when it builds the envelope.
pub fn to_map(event: BookclubArchived) -> Payload {
  dict.from_list([
    #(atom("event_type"), dynamic.string(event_type())),
    #(atom("club_id"), dynamic.string(event.club_id)),
    #(atom("name"), dynamic.string(event.name)),
    #(atom("initiated_by"), dynamic.string(event.initiated_by)),
    #(atom("initiated_at"), dynamic.int(event.initiated_at)),
    #(atom("archived_by"), dynamic.string(event.archived_by)),
    #(atom("archived_at"), dynamic.int(event.archived_at)),
  ])
}

pub fn from_map(map: Payload) -> Result(BookclubArchived, dynamic.Dynamic) {
  case desk.get_string(map, "club_id"), desk.get_string(map, "name") {
    Ok(club_id), Ok(name) ->
      Ok(BookclubArchived(
        club_id: club_id,
        name: name,
        initiated_by: desk.get_string_default(map, "initiated_by", ""),
        initiated_at: desk.get_int_default(map, "initiated_at", 0),
        archived_by: desk.get_string_default(map, "archived_by", ""),
        archived_at: desk.get_int_default(map, "archived_at", 0),
      ))
    _, _ -> Error(desk.missing_required_fields())
  }
}

pub fn get_club_id(event: BookclubArchived) -> String {
  event.club_id
}

pub fn get_name(event: BookclubArchived) -> String {
  event.name
}

pub fn get_initiated_by(event: BookclubArchived) -> String {
  event.initiated_by
}

pub fn get_initiated_at(event: BookclubArchived) -> Int {
  event.initiated_at
}

pub fn get_archived_by(event: BookclubArchived) -> String {
  event.archived_by
}

pub fn get_archived_at(event: BookclubArchived) -> Int {
  event.archived_at
}
