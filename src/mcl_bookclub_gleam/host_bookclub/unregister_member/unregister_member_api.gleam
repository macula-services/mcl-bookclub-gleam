//// unregister_member_api: the HTTP entry point for unregister_member_v1.
////
//// Pure, like every entry point here. The member id is REQUIRED.

import mcl_bookclub_gleam/host_bookclub/unregister_member/maybe_unregister_member
import mcl_bookclub_gleam/host_bookclub/unregister_member/unregister_member_v1
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/payload.{type Payload}

/// Params arrive atom-keyed (the facade JSON-decodes with atom labels).
/// Both fields are REQUIRED: an unregister names an existing member and
/// who did the unregistering.
pub fn handle(params: Payload) -> desk.DispatchResult {
  case unregister_member_v1.new(params) {
    Ok(command) -> maybe_unregister_member.dispatch(command)
    Error(e) -> Error(e)
  }
}
