//// The party_planned_v1 event: a fact about the past.
////
//// It carries the club's NEW party count, echoed from the aggregate
//// state: a downstream consumer can rebuild the club's party tally from
//// this event alone, and the fold is an absolute assignment (applying the
//// same event twice sets the same count), never a relative increment.

import gleam/dict
import gleam/dynamic
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/mesh
import mcl_bookclub_gleam/internal/payload.{atom, type Payload}

pub type PartyPlanned {
  PartyPlanned(
    club_id: String,
    parties_planned: Int,
    planned_at: Int,
  )
}

/// The binary event type -- what evoq_event_handler's interested_in/0
/// matches on.
pub fn event_type() -> String {
  "party_planned_v1"
}

pub fn new(params: Payload) -> Result(PartyPlanned, dynamic.Dynamic) {
  case desk.get_string(params, "club_id"), desk.get_int(params, "parties_planned") {
    Ok(club_id), Ok(parties_planned) ->
      Ok(PartyPlanned(
        club_id: club_id,
        parties_planned: parties_planned,
        planned_at: mesh.now_ms(mesh.millisecond()),
      ))
    _, _ -> Error(desk.missing_required_fields())
  }
}

/// The stored payload: atom keys, event_type included -- evoq extracts the
/// type with an atom lookup when it builds the envelope.
pub fn to_map(event: PartyPlanned) -> Payload {
  dict.from_list([
    #(atom("event_type"), dynamic.string(event_type())),
    #(atom("club_id"), dynamic.string(event.club_id)),
    #(atom("parties_planned"), dynamic.int(event.parties_planned)),
    #(atom("planned_at"), dynamic.int(event.planned_at)),
  ])
}

pub fn from_map(map: Payload) -> Result(PartyPlanned, dynamic.Dynamic) {
  case desk.get_string(map, "club_id") {
    Ok(club_id) ->
      Ok(PartyPlanned(
        club_id: club_id,
        parties_planned: desk.get_int_default(map, "parties_planned", 0),
        planned_at: desk.get_int_default(map, "planned_at", 0),
      ))
    Error(e) -> Error(e)
  }
}

pub fn get_club_id(event: PartyPlanned) -> String {
  event.club_id
}

pub fn get_parties_planned(event: PartyPlanned) -> Int {
  event.parties_planned
}

pub fn get_planned_at(event: PartyPlanned) -> Int {
  event.planned_at
}
