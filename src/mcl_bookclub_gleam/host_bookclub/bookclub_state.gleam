//// The bookclub aggregate's state: the record, its fold, its shape.
////
//// The state module is the only module that sees the record. The
//// aggregate and the handlers work through semantic getters, so a change
//// to what the state keeps never ripples past this file.
////
//// The state remembers the club's BIRTH DETAILS (initiated_by,
//// initiated_at), not just its name -- load-bearing, because events that
//// downstream consumers need must be self-contained, and the aggregate is
//// the only place with the state to echo those details into them.

import gleam/dict
import gleam/dynamic
import mcl_bookclub_gleam/host_bookclub/bookclub_status
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/evoq
import mcl_bookclub_gleam/internal/payload.{type Payload, atom}

pub type BookclubState {
  BookclubState(
    club_id: String,
    name: String,
    initiated_by: String,
    initiated_at: Int,
    parties_planned: Int,
    status: Int,
  )
}

pub fn new(club_id: String) -> BookclubState {
  BookclubState(
    club_id: club_id,
    name: "",
    initiated_by: "",
    initiated_at: 0,
    parties_planned: 0,
    status: 0,
  )
}

/// Fold one event. evoq hands apply/2 TWO SHAPES for the same event: the
/// raw event right after execute/2, with the business fields inline and no
/// `data' key, and the stored envelope on reload, with the business fields
/// under `data'. Read tolerantly -- matching one shape only is a bug that
/// shows up on the second command, never the first.
pub fn apply_event(state: BookclubState, event: Payload) -> BookclubState {
  case desk.event_type_of(event) {
    "bookclub_initiated_v1" -> {
      let data = desk.event_data(event)
      BookclubState(
        ..state,
        name: desk.get_string_default(data, "name", ""),
        initiated_by: desk.get_string_default(data, "initiated_by", ""),
        initiated_at: desk.get_int_default(data, "initiated_at", 0),
        status: evoq.bit_set(state.status, bookclub_status.initiated()),
      )
    }
    "bookclub_archived_v1" ->
      BookclubState(
        ..state,
        status: evoq.bit_set(state.status, bookclub_status.archived()),
      )
    "party_planned_v1" -> {
      let data = desk.event_data(event)
      BookclubState(
        ..state,
        parties_planned: desk.get_int_default(data, "parties_planned", 0),
      )
    }
    _ -> state
  }
}

/// The snapshot shape: the same map the twins snapshot, atom-keyed.
pub fn to_map(state: BookclubState) -> Payload {
  dict.from_list([
    #(atom("club_id"), dynamic.string(state.club_id)),
    #(atom("name"), dynamic.string(state.name)),
    #(atom("initiated_by"), dynamic.string(state.initiated_by)),
    #(atom("initiated_at"), dynamic.int(state.initiated_at)),
    #(atom("parties_planned"), dynamic.int(state.parties_planned)),
    #(atom("status"), dynamic.int(state.status)),
  ])
}

pub fn from_map(map: Payload) -> Result(BookclubState, dynamic.Dynamic) {
  case desk.get_string(map, "club_id") {
    Ok(club_id) ->
      Ok(BookclubState(
        club_id: club_id,
        name: desk.get_string_default(map, "name", ""),
        initiated_by: desk.get_string_default(map, "initiated_by", ""),
        initiated_at: desk.get_int_default(map, "initiated_at", 0),
        parties_planned: desk.get_int_default(map, "parties_planned", 0),
        status: desk.get_int_default(map, "status", 0),
      ))
    Error(e) -> Error(e)
  }
}

pub fn club_id(state: BookclubState) -> String {
  state.club_id
}

pub fn name(state: BookclubState) -> String {
  state.name
}

pub fn initiated_by(state: BookclubState) -> String {
  state.initiated_by
}

pub fn initiated_at(state: BookclubState) -> Int {
  state.initiated_at
}

pub fn parties_planned(state: BookclubState) -> Int {
  state.parties_planned
}

pub fn is_initiated(state: BookclubState) -> Bool {
  evoq.bit_has(state.status, bookclub_status.initiated())
}

pub fn is_archived(state: BookclubState) -> Bool {
  evoq.bit_has(state.status, bookclub_status.archived())
}
