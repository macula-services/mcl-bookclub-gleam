//// The register_member_v1 command: a person joins the club.
////
//// The command names the member's stream id (minted, never derived from
//// the human name), the club being joined, and the member's name. The
//// payload keys are ATOMS -- evoq reads command_type with an atom lookup.

import gleam/dict
import gleam/dynamic
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/ids
import mcl_bookclub_gleam/internal/payload.{type Payload, atom}

pub type RegisterMember {
  RegisterMember(
    member_id: String,
    club_id: String,
    name: String,
    club_name: String,
  )
}

/// The command's type atom -- the same atom to_map/1 stamps into the
/// payload, which the aggregate's execute/2 dispatches on.
pub fn command_type() -> dynamic.Dynamic {
  atom("register_member_v1")
}

/// Mint the member's stream id. The AggregateId IS the reckon stream id
/// (`^[a-z]{1,32}-[a-f0-9]{32}$'), so the human name goes in the payload
/// and this derived id is what the command is addressed to. Never
/// hand-roll the suffix; reckon_gater_stream_id:new/1 mints the contract.
pub fn mint_member_id() -> String {
  ids.mint_stream_id("member")
}

/// The command's payload: required fields are binaries, club_name
/// defaults to the empty binary (the entry point stamps it in later).
pub fn new(params: Payload) -> Result(RegisterMember, dynamic.Dynamic) {
  case
    desk.get_string(params, "member_id"),
    desk.get_string(params, "club_id"),
    desk.get_string(params, "name")
  {
    Ok(member_id), Ok(club_id), Ok(name) ->
      case member_id != "" && club_id != "" && name != "" {
        True ->
          Ok(RegisterMember(
            member_id: member_id,
            club_id: club_id,
            name: name,
            club_name: desk.get_string_default(params, "club_name", ""),
          ))
        False -> Error(desk.invalid_params())
      }
    _, _, _ -> Error(desk.missing_required_fields())
  }
}

/// Checks about the world, not the shape: both stream ids must satisfy
/// the reckon-db stream contract.
pub fn validate(command: RegisterMember) -> Result(Nil, dynamic.Dynamic) {
  desk.validate_stream_ids([command.member_id, command.club_id])
}

/// The payload the aggregate's execute/2 sees: atom keys, command_type
/// included.
pub fn to_map(command: RegisterMember) -> Payload {
  dict.from_list([
    #(command_type_key(), command_type()),
    #(atom("member_id"), dynamic.string(command.member_id)),
    #(atom("club_id"), dynamic.string(command.club_id)),
    #(atom("name"), dynamic.string(command.name)),
    #(atom("club_name"), dynamic.string(command.club_name)),
  ])
}

pub fn from_map(params: Payload) -> Result(RegisterMember, dynamic.Dynamic) {
  new(params)
}

/// The stream the command is addressed to: the member's own id.
pub fn stream_id(command: RegisterMember) -> String {
  command.member_id
}

pub fn get_member_id(command: RegisterMember) -> String {
  command.member_id
}

pub fn get_club_id(command: RegisterMember) -> String {
  command.club_id
}

pub fn get_name(command: RegisterMember) -> String {
  command.name
}

pub fn get_club_name(command: RegisterMember) -> String {
  command.club_name
}

fn command_type_key() -> dynamic.Dynamic {
  atom("command_type")
}
