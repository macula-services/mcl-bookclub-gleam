//// Projects reading_started_v1 into the readings table.
////
//// Same idempotent shape: INSERT OR REPLACE keyed on the stream id, the
//// row carrying the applied position, the status string from
//// reading_status (Demon 68). A fresh reading has 0 pages and no
//// finished_at -- those arrive with reading_finished_v1.

import gleam/dynamic
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/payload.{type Payload}
import mcl_bookclub_gleam/internal/projection
import mcl_bookclub_gleam/host_bookclub/reading_status
import mcl_bookclub_gleam/project_bookclub/bookclub_read_model_store

pub fn interested_in() -> List(String) {
  projection.interested_in(["reading_started_v1"])
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
    "INSERT OR REPLACE INTO readings"
    <> " (reading_id, member_id, book_id, status, started_at, pages_read,"
    <> "  finished_at, event_id, version)"
    <> " VALUES (?, ?, ?, ?, ?, 0, NULL, ?, ?)",
    [
      dynamic.string(desk.get_string_default(data, "reading_id", "")),
      dynamic.string(desk.get_string_default(data, "member_id", "")),
      dynamic.string(desk.get_string_default(data, "book_id", "")),
      dynamic.string(reading_status.to_string(reading_status.in_progress())),
      dynamic.int(desk.get_int_default(data, "started_at", 0)),
      dynamic.string(projection.event_id_of(event)),
      dynamic.int(projection.version_of(event)),
    ],
  ) {
    Ok(_) -> Ok(state)
    Error(reason) -> Error(projection.store_error(reason))
  }
}
