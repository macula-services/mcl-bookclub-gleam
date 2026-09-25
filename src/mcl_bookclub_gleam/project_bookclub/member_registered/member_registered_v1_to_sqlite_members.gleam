//// Projects member_registered_v1 into the members table.
////
//// Same idempotent shape: INSERT OR REPLACE keyed on the stream id, the
//// row carrying the applied position, the status string from
//// member_status (Demon 68).

import gleam/dynamic
import mcl_bookclub_gleam/host_bookclub/member_status
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/payload.{type Payload}
import mcl_bookclub_gleam/internal/projection
import mcl_bookclub_gleam/project_bookclub/bookclub_read_model_store

pub fn interested_in() -> List(String) {
  projection.interested_in(["member_registered_v1"])
}

pub fn replay_policy() -> dynamic.Dynamic {
  projection.replay_policy()
}

pub fn init(config: Payload) -> Result(dynamic.Dynamic, dynamic.Dynamic) {
  projection.init(config)
}

pub fn handle_event(
  _event_type: String,
  event: Payload,
  _metadata: Payload,
  state: dynamic.Dynamic,
) -> Result(dynamic.Dynamic, dynamic.Dynamic) {
  let data = projection.data_of(event)
  case
    bookclub_read_model_store.exec(
      "INSERT OR REPLACE INTO members"
        <> " (member_id, club_id, name, status, registered_at, event_id, version)"
        <> " VALUES (?, ?, ?, ?, ?, ?, ?)",
      [
        dynamic.string(desk.get_string_default(data, "member_id", "")),
        dynamic.string(desk.get_string_default(data, "club_id", "")),
        dynamic.string(desk.get_string_default(data, "name", "")),
        dynamic.string(member_status.to_string(member_status.registered())),
        dynamic.int(desk.get_int_default(data, "registered_at", 0)),
        dynamic.string(projection.event_id_of(event)),
        dynamic.int(projection.version_of(event)),
      ],
    )
  {
    Ok(_) -> Ok(state)
    Error(reason) -> Error(projection.store_error(reason))
  }
}
