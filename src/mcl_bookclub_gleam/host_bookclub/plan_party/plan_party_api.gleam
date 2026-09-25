//// plan_party_api: the HTTP entry point for plan_party_v1.
////
//// Pure, like every entry point here. The club id is REQUIRED.

import mcl_bookclub_gleam/host_bookclub/plan_party/maybe_plan_party
import mcl_bookclub_gleam/host_bookclub/plan_party/plan_party_v1
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/payload.{type Payload}

/// Params arrive atom-keyed (the facade JSON-decodes with atom labels).
/// The club id is required -- the entry point does not mint one.
pub fn handle(params: Payload) -> desk.DispatchResult {
  case plan_party_v1.new(params) {
    Ok(command) -> maybe_plan_party.dispatch(command)
    Error(e) -> Error(e)
  }
}
