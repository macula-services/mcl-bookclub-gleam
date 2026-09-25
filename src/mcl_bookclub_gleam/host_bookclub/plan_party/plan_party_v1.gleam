//// The plan_party_v1 command: the club plans a party.
////
//// The command names the club's stream id and nothing else -- the party
//// count lives in the aggregate state, incremented there and echoed into
//// the event. The payload keys are ATOMS -- evoq reads command_type with
//// an atom lookup.

import gleam/dict
import gleam/dynamic
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/payload.{type Payload, atom}

pub type PlanParty {
  PlanParty(club_id: String)
}

/// The command's type atom -- the same atom to_map/1 stamps into the
/// payload, which the aggregate's execute/2 dispatches on.
pub fn command_type() -> dynamic.Dynamic {
  atom("plan_party_v1")
}

/// The command's payload: the club's stream id is the one required field.
pub fn new(params: Payload) -> Result(PlanParty, dynamic.Dynamic) {
  case desk.get_string(params, "club_id") {
    Ok(club_id) -> new_when_valid(club_id)
    Error(_) -> Error(desk.missing_required_fields())
  }
}

fn new_when_valid(club_id: String) -> Result(PlanParty, dynamic.Dynamic) {
  case club_id != "" {
    True -> Ok(PlanParty(club_id: club_id))
    False -> Error(desk.invalid_params())
  }
}

/// Checks about the world, not the shape: the stream id must satisfy the
/// reckon-db stream contract.
pub fn validate(command: PlanParty) -> Result(Nil, dynamic.Dynamic) {
  desk.validate_stream_ids([command.club_id])
}

/// The payload the aggregate's execute/2 sees: atom keys, command_type
/// included.
pub fn to_map(command: PlanParty) -> Payload {
  dict.from_list([
    #(command_type_key(), command_type()),
    #(atom("club_id"), dynamic.string(command.club_id)),
  ])
}

pub fn from_map(params: Payload) -> Result(PlanParty, dynamic.Dynamic) {
  new(params)
}

/// The stream the command is addressed to: the club's own id.
pub fn stream_id(command: PlanParty) -> String {
  command.club_id
}

pub fn get_club_id(command: PlanParty) -> String {
  command.club_id
}

fn command_type_key() -> dynamic.Dynamic {
  atom("command_type")
}
