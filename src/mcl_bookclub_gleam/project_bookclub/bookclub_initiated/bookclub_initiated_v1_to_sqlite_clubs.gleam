//// Projects bookclub_initiated_v1 into the clubs table.
////
//// The same idempotent shape as every projection: INSERT OR REPLACE keyed
//// on the stream id, the row carrying the applied position (event_id,
//// version), and the status string taken from bookclub_status -- never a
//// literal of this file's own (Demon 68).

import gleam/dynamic
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/payload.{type Payload}
import mcl_bookclub_gleam/internal/projection
import mcl_bookclub_gleam/host_bookclub/bookclub_status
import mcl_bookclub_gleam/project_bookclub/bookclub_read_model_store

pub fn interested_in() -> List(String) {
  projection.interested_in(["bookclub_initiated_v1"])
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
  case bookclub_read_model_store.exec(
    "INSERT OR REPLACE INTO clubs"
    <> " (club_id, name, status, initiated_by, initiated_at, event_id, version)"
    <> " VALUES (?, ?, ?, ?, ?, ?, ?)",
    [
      dynamic.string(desk.get_string_default(data, "club_id", "")),
      dynamic.string(desk.get_string_default(data, "name", "")),
      dynamic.string(bookclub_status.to_string(bookclub_status.initiated())),
      dynamic.string(desk.get_string_default(data, "initiated_by", "")),
      dynamic.int(desk.get_int_default(data, "initiated_at", 0)),
      dynamic.string(projection.event_id_of(event)),
      dynamic.int(projection.version_of(event)),
    ],
  ) {
    Ok(_) -> Ok(state)
    Error(reason) -> Error(projection.store_error(reason))
  }
}
