//// initiate_bookclub_api: the HTTP entry point for initiate_bookclub_v1.
////
//// Pure, like every entry point here -- no cowboy, no mesh. The club id
//// is minted when the operator does not bring one; the event echoes it
//// back.

import gleam/dict
import gleam/dynamic
import mcl_bookclub_gleam/host_bookclub/initiate_bookclub/initiate_bookclub_v1
import mcl_bookclub_gleam/host_bookclub/initiate_bookclub/maybe_initiate_bookclub
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/payload.{type Payload, atom}

/// Params arrive atom-keyed (the facade JSON-decodes with atom labels). A
/// missing club_id is minted; the event echoes it back.
pub fn handle(params: Payload) -> desk.DispatchResult {
  let club_id = case desk.get_string(params, "club_id") {
    Ok("") -> initiate_bookclub_v1.mint_club_id()
    Ok(id) -> id
    Error(_) -> initiate_bookclub_v1.mint_club_id()
  }
  let params = dict.insert(params, atom("club_id"), dynamic.string(club_id))
  case initiate_bookclub_v1.new(params) {
    Ok(command) -> maybe_initiate_bookclub.dispatch(command)
    Error(e) -> Error(e)
  }
}
