//// The member_registered_v1 event: a fact about the past.
////
//// Self-contained: it carries the club the member joined, so any
//// downstream consumer (the plan_party policy, the mesh emitter, the
//// projection) reads one event and knows everything it needs.

import gleam/dict
import gleam/dynamic
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/ids
import mcl_bookclub_gleam/internal/payload.{type Payload, atom}

pub type MemberRegistered {
  MemberRegistered(
    member_id: String,
    club_id: String,
    name: String,
    club_name: String,
    registered_at: Int,
  )
}

/// The binary event type -- what evoq_event_handler's interested_in/0
/// matches on.
pub fn event_type() -> String {
  "member_registered_v1"
}

pub fn new(params: Payload) -> Result(MemberRegistered, dynamic.Dynamic) {
  case
    desk.get_string(params, "member_id"),
    desk.get_string(params, "club_id"),
    desk.get_string(params, "name")
  {
    Ok(member_id), Ok(club_id), Ok(name) ->
      Ok(MemberRegistered(
        member_id: member_id,
        club_id: club_id,
        name: name,
        club_name: desk.get_string_default(params, "club_name", ""),
        registered_at: ids.now_ms(ids.millisecond()),
      ))
    _, _, _ -> Error(desk.missing_required_fields())
  }
}

/// The stored payload: atom keys, event_type included -- evoq extracts
/// the type with an atom lookup when it builds the envelope.
pub fn to_map(event: MemberRegistered) -> Payload {
  dict.from_list([
    #(atom("event_type"), dynamic.string(event_type())),
    #(atom("member_id"), dynamic.string(event.member_id)),
    #(atom("club_id"), dynamic.string(event.club_id)),
    #(atom("name"), dynamic.string(event.name)),
    #(atom("club_name"), dynamic.string(event.club_name)),
    #(atom("registered_at"), dynamic.int(event.registered_at)),
  ])
}

pub fn from_map(map: Payload) -> Result(MemberRegistered, dynamic.Dynamic) {
  case desk.get_string(map, "member_id") {
    Ok(member_id) ->
      Ok(MemberRegistered(
        member_id: member_id,
        club_id: desk.get_string_default(map, "club_id", ""),
        name: desk.get_string_default(map, "name", ""),
        club_name: desk.get_string_default(map, "club_name", ""),
        registered_at: desk.get_int_default(map, "registered_at", 0),
      ))
    Error(e) -> Error(e)
  }
}

pub fn get_member_id(event: MemberRegistered) -> String {
  event.member_id
}

pub fn get_club_id(event: MemberRegistered) -> String {
  event.club_id
}

pub fn get_name(event: MemberRegistered) -> String {
  event.name
}

pub fn get_registered_at(event: MemberRegistered) -> Int {
  event.registered_at
}
