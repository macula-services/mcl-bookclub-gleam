//// The initiate_bookclub_v1 command: what a caller asks for.
////
//// A command is a record with typed getters, one `to_map/1' that becomes
//// the payload the aggregate's execute/2 sees, and one validate/1 for the
//// checks that are about the world (here: the stream id the command
//// names). The payload keys are ATOMS -- evoq reads command_type with an
//// atom lookup.

import gleam/dict
import gleam/dynamic
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/ids
import mcl_bookclub_gleam/internal/payload.{atom, type Payload}

pub type InitiateBookclub {
  InitiateBookclub(
    club_id: String,
    name: String,
    initiated_by: String,
  )
}

/// The command's type atom -- the same atom to_map/1 stamps into the
/// payload, which the aggregate's execute/2 dispatches on.
pub fn command_type() -> dynamic.Dynamic {
  atom("initiate_bookclub_v1")
}

/// Mint the club's stream id. The AggregateId IS the reckon stream id
/// (`^[a-z]{1,32}-[a-f0-9]{32}$'), so the human-readable name goes in the
/// payload and this derived id is what the command is addressed to. Never
/// hand-roll the suffix; reckon_gater_stream_id:new/1 mints the contract.
pub fn mint_club_id() -> String {
  ids.mint_stream_id("bookclub")
}

/// The command's payload: all three fields are required binaries.
pub fn new(params: Payload) -> Result(InitiateBookclub, dynamic.Dynamic) {
  case desk.get_string(params, "club_id"),
    desk.get_string(params, "name"),
    desk.get_string(params, "initiated_by")
  {
    Ok(club_id), Ok(name), Ok(initiated_by) ->
      case club_id != "" && name != "" && initiated_by != "" {
        True ->
          Ok(InitiateBookclub(
            club_id: club_id,
            name: name,
            initiated_by: initiated_by,
          ))
        False -> Error(desk.invalid_params())
      }
    _, _, _ -> Error(desk.missing_required_fields())
  }
}

/// Checks about the world, not the shape: the stream id must satisfy the
/// reckon-db stream contract.
pub fn validate(command: InitiateBookclub) -> Result(Nil, dynamic.Dynamic) {
  desk.validate_stream_ids([command.club_id])
}

/// The payload the aggregate's execute/2 sees: atom keys, command_type
/// included.
pub fn to_map(command: InitiateBookclub) -> Payload {
  dict.from_list([
    #(command_type_key(), command_type()),
    #(atom("club_id"), dynamic.string(command.club_id)),
    #(atom("name"), dynamic.string(command.name)),
    #(atom("initiated_by"), dynamic.string(command.initiated_by)),
  ])
}

pub fn from_map(params: Payload) -> Result(InitiateBookclub, dynamic.Dynamic) {
  new(params)
}

/// The stream the command is addressed to: the club's own id.
pub fn stream_id(command: InitiateBookclub) -> String {
  command.club_id
}

pub fn get_club_id(command: InitiateBookclub) -> String {
  command.club_id
}

pub fn get_name(command: InitiateBookclub) -> String {
  command.name
}

pub fn get_initiated_by(command: InitiateBookclub) -> String {
  command.initiated_by
}

fn command_type_key() -> dynamic.Dynamic {
  atom("command_type")
}
