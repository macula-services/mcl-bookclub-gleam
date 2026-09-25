//// The member aggregate's state: the record, its fold, its shape.
////
//// The state module is the only module that sees the record. Like the
//// club's state, it remembers the birth details (club_id, name,
//// registered_at), so the unregistered event can echo them and stay
//// self-contained for its projection.

import gleam/dict
import gleam/dynamic
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/evoq
import mcl_bookclub_gleam/internal/payload.{atom, type Payload}
import mcl_bookclub_gleam/host_bookclub/member_status

pub type MemberState {
  MemberState(
    member_id: String,
    club_id: String,
    name: String,
    registered_at: Int,
    status: Int,
  )
}

pub fn new(member_id: String) -> MemberState {
  MemberState(
    member_id: member_id,
    club_id: "",
    name: "",
    registered_at: 0,
    status: 0,
  )
}

/// Fold one event. Read tolerantly: the raw event has its business fields
/// inline, the stored envelope has them under `data'.
pub fn apply_event(state: MemberState, event: Payload) -> MemberState {
  case desk.event_type_of(event) {
    "member_registered_v1" -> {
      let data = desk.event_data(event)
      MemberState(
        ..state,
        club_id: desk.get_string_default(data, "club_id", ""),
        name: desk.get_string_default(data, "name", ""),
        registered_at: desk.get_int_default(data, "registered_at", 0),
        status: evoq.bit_set(state.status, member_status.registered()),
      )
    }
    "member_unregistered_v1" ->
      MemberState(
        ..state,
        status: evoq.bit_set(state.status, member_status.unregistered()),
      )
    _ -> state
  }
}

pub fn to_map(state: MemberState) -> Payload {
  dict.from_list([
    #(atom("member_id"), dynamic.string(state.member_id)),
    #(atom("club_id"), dynamic.string(state.club_id)),
    #(atom("name"), dynamic.string(state.name)),
    #(atom("registered_at"), dynamic.int(state.registered_at)),
    #(atom("status"), dynamic.int(state.status)),
  ])
}

pub fn from_map(map: Payload) -> Result(MemberState, dynamic.Dynamic) {
  case desk.get_string(map, "member_id") {
    Ok(member_id) ->
      Ok(MemberState(
        member_id: member_id,
        club_id: desk.get_string_default(map, "club_id", ""),
        name: desk.get_string_default(map, "name", ""),
        registered_at: desk.get_int_default(map, "registered_at", 0),
        status: desk.get_int_default(map, "status", 0),
      ))
    Error(e) -> Error(e)
  }
}

pub fn member_id(state: MemberState) -> String {
  state.member_id
}

pub fn club_id(state: MemberState) -> String {
  state.club_id
}

pub fn name(state: MemberState) -> String {
  state.name
}

pub fn registered_at(state: MemberState) -> Int {
  state.registered_at
}

pub fn is_registered(state: MemberState) -> Bool {
  evoq.bit_has(state.status, member_status.registered())
}

pub fn is_unregistered(state: MemberState) -> Bool {
  evoq.bit_has(state.status, member_status.unregistered())
}
