//// The member_unregistered_v1 event: a fact about the past.
////
//// SELF-CONTAINED, like the club's archived event: it echoes the member's
//// club, name and registration time from the aggregate state, so its
//// projection stays an absolute, idempotent write that never depends on the
//// registered event having arrived first.

import gleam/dict
import gleam/dynamic
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/ids
import mcl_bookclub_gleam/internal/payload.{atom, type Payload}

pub type MemberUnregistered {
  MemberUnregistered(
    member_id: String,
    club_id: String,
    name: String,
    registered_at: Int,
    unregistered_by: String,
    unregistered_at: Int,
  )
}

/// The binary event type -- what evoq_event_handler's interested_in/0
/// matches on.
pub fn event_type() -> String {
  "member_unregistered_v1"
}

pub fn new(params: Payload) -> Result(MemberUnregistered, dynamic.Dynamic) {
  case desk.get_string(params, "member_id"),
    desk.get_string(params, "club_id"),
    desk.get_string(params, "name"),
    desk.get_string(params, "unregistered_by")
  {
    Ok(member_id), Ok(club_id), Ok(name), Ok(unregistered_by) ->
      Ok(MemberUnregistered(
        member_id: member_id,
        club_id: club_id,
        name: name,
        registered_at: desk.get_int_default(params, "registered_at", 0),
        unregistered_by: unregistered_by,
        unregistered_at: ids.now_ms(ids.millisecond()),
      ))
    _, _, _, _ -> Error(desk.missing_required_fields())
  }
}

/// The stored payload: atom keys, event_type included -- evoq extracts
/// the type with an atom lookup when it builds the envelope.
pub fn to_map(event: MemberUnregistered) -> Payload {
  dict.from_list([
    #(atom("event_type"), dynamic.string(event_type())),
    #(atom("member_id"), dynamic.string(event.member_id)),
    #(atom("club_id"), dynamic.string(event.club_id)),
    #(atom("name"), dynamic.string(event.name)),
    #(atom("registered_at"), dynamic.int(event.registered_at)),
    #(atom("unregistered_by"), dynamic.string(event.unregistered_by)),
    #(atom("unregistered_at"), dynamic.int(event.unregistered_at)),
  ])
}

pub fn from_map(map: Payload) -> Result(MemberUnregistered, dynamic.Dynamic) {
  case desk.get_string(map, "member_id") {
    Ok(member_id) ->
      Ok(MemberUnregistered(
        member_id: member_id,
        club_id: desk.get_string_default(map, "club_id", ""),
        name: desk.get_string_default(map, "name", ""),
        registered_at: desk.get_int_default(map, "registered_at", 0),
        unregistered_by: desk.get_string_default(map, "unregistered_by", ""),
        unregistered_at: desk.get_int_default(map, "unregistered_at", 0),
      ))
    Error(e) -> Error(e)
  }
}

pub fn get_member_id(event: MemberUnregistered) -> String {
  event.member_id
}

pub fn get_club_id(event: MemberUnregistered) -> String {
  event.club_id
}

pub fn get_name(event: MemberUnregistered) -> String {
  event.name
}

pub fn get_registered_at(event: MemberUnregistered) -> Int {
  event.registered_at
}

pub fn get_unregistered_by(event: MemberUnregistered) -> String {
  event.unregistered_by
}

pub fn get_unregistered_at(event: MemberUnregistered) -> Int {
  event.unregistered_at
}
