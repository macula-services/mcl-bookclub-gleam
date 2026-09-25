//// start_reading_api: the HTTP entry point for start_reading_v1.
////
//// Pure, like every entry point here -- no cowboy, no mesh. The reading
//// id is minted when the operator does not bring one -- the reading is the
//// child, and the entry point is the member's side that identifies it.

import gleam/dict
import gleam/dynamic
import mcl_bookclub_gleam/host_bookclub/start_reading/maybe_start_reading
import mcl_bookclub_gleam/host_bookclub/start_reading/start_reading_v1
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/payload.{type Payload, atom}

/// Params arrive atom-keyed (the facade JSON-decodes with atom labels). A
/// missing reading_id is minted; the event echoes it back.
pub fn handle(params: Payload) -> desk.DispatchResult {
  let reading_id = case desk.get_string(params, "reading_id") {
    Ok("") -> start_reading_v1.mint_reading_id()
    Ok(id) -> id
    Error(_) -> start_reading_v1.mint_reading_id()
  }
  let params =
    dict.insert(params, atom("reading_id"), dynamic.string(reading_id))
  case start_reading_v1.new(params) {
    Ok(command) -> maybe_start_reading.dispatch(command)
    Error(e) -> Error(e)
  }
}
