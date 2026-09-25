//// finish_reading_api: the HTTP entry point for finish_reading_v1.
////
//// Pure, like every entry point here -- no cowboy, no mesh. The reading id
//// and the pages read are REQUIRED -- a finish names an in-progress reading.

import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/payload.{type Payload}
import mcl_bookclub_gleam/host_bookclub/finish_reading/finish_reading_v1
import mcl_bookclub_gleam/host_bookclub/finish_reading/maybe_finish_reading

/// The reading id and the pages read are both required; new/1 reads them
/// tolerantly and refuses a missing field with missing_required_fields.
/// Dispatch is the only path out.
pub fn handle(params: Payload) -> desk.DispatchResult {
  case finish_reading_v1.new(params) {
    Ok(command) -> maybe_finish_reading.dispatch(command)
    Error(e) -> Error(e)
  }
}
