//// The archive_bookclub_v1 command: soft-delete the club.
////
//// `archive', the house soft-delete verb -- never delete. The command
//// names the club's stream id and who archived it; everything else the
//// archive needs comes from the aggregate state, echoed into the event.

import gleam/dict
import gleam/dynamic
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/payload.{atom, type Payload}

pub type ArchiveBookclub {
  ArchiveBookclub(
    club_id: String,
    archived_by: String,
  )
}

/// The command's type atom -- the same atom to_map/1 stamps into the
/// payload, which the aggregate's execute/2 dispatches on.
pub fn command_type() -> dynamic.Dynamic {
  atom("archive_bookclub_v1")
}

pub fn new(params: Payload) -> Result(ArchiveBookclub, dynamic.Dynamic) {
  case desk.get_string(params, "club_id"),
    desk.get_string(params, "archived_by")
  {
    Ok(club_id), Ok(archived_by) ->
      case club_id != "" && archived_by != "" {
        True ->
          Ok(ArchiveBookclub(
            club_id: club_id,
            archived_by: archived_by,
          ))
        False -> Error(desk.invalid_params())
      }
    _, _ -> Error(desk.missing_required_fields())
  }
}

/// Checks about the world, not the shape: the stream id must satisfy the
/// reckon-db stream contract, or the append is refused.
pub fn validate(command: ArchiveBookclub) -> Result(Nil, dynamic.Dynamic) {
  desk.validate_stream_ids([command.club_id])
}

/// The payload the aggregate's execute/2 sees: atom keys, command_type
/// included.
pub fn to_map(command: ArchiveBookclub) -> Payload {
  dict.from_list([
    #(command_type_key(), command_type()),
    #(atom("club_id"), dynamic.string(command.club_id)),
    #(atom("archived_by"), dynamic.string(command.archived_by)),
  ])
}

pub fn from_map(params: Payload) -> Result(ArchiveBookclub, dynamic.Dynamic) {
  new(params)
}

/// The stream the command is addressed to: the club's own id.
pub fn stream_id(command: ArchiveBookclub) -> String {
  command.club_id
}

pub fn get_club_id(command: ArchiveBookclub) -> String {
  command.club_id
}

pub fn get_archived_by(command: ArchiveBookclub) -> String {
  command.archived_by
}

fn command_type_key() -> dynamic.Dynamic {
  atom("command_type")
}
