//// The unregister_member_v1 command: soft-delete the member.
////
//// `unregister', the club-domain verb for a member leaving -- never
//// delete. Everything else the unregistered event needs comes from the
//// aggregate state, echoed into the event.

import gleam/dict
import gleam/dynamic
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/payload.{type Payload, atom}

pub type UnregisterMember {
  UnregisterMember(member_id: String, unregistered_by: String)
}

/// The command's type atom -- the same atom to_map/1 stamps into the
/// payload, which the aggregate's execute/2 dispatches on.
pub fn command_type() -> dynamic.Dynamic {
  atom("unregister_member_v1")
}

pub fn new(params: Payload) -> Result(UnregisterMember, dynamic.Dynamic) {
  case
    desk.get_string(params, "member_id"),
    desk.get_string(params, "unregistered_by")
  {
    Ok(member_id), Ok(unregistered_by) ->
      new_when_valid(member_id, unregistered_by)
    _, _ -> Error(desk.missing_required_fields())
  }
}

fn new_when_valid(
  member_id: String,
  unregistered_by: String,
) -> Result(UnregisterMember, dynamic.Dynamic) {
  case member_id != "" && unregistered_by != "" {
    True ->
      Ok(UnregisterMember(
        member_id: member_id,
        unregistered_by: unregistered_by,
      ))
    False -> Error(desk.invalid_params())
  }
}

/// Checks about the world, not the shape: the stream id must satisfy the
/// reckon-db stream contract, or the append is refused.
pub fn validate(command: UnregisterMember) -> Result(Nil, dynamic.Dynamic) {
  desk.validate_stream_ids([command.member_id])
}

/// The payload the aggregate's execute/2 sees: atom keys, command_type
/// included.
pub fn to_map(command: UnregisterMember) -> Payload {
  dict.from_list([
    #(command_type_key(), command_type()),
    #(atom("member_id"), dynamic.string(command.member_id)),
    #(atom("unregistered_by"), dynamic.string(command.unregistered_by)),
  ])
}

pub fn from_map(params: Payload) -> Result(UnregisterMember, dynamic.Dynamic) {
  new(params)
}

/// The stream the command is addressed to: the member's own id.
pub fn stream_id(command: UnregisterMember) -> String {
  command.member_id
}

pub fn get_member_id(command: UnregisterMember) -> String {
  command.member_id
}

pub fn get_unregistered_by(command: UnregisterMember) -> String {
  command.unregistered_by
}

fn command_type_key() -> dynamic.Dynamic {
  atom("command_type")
}
