//// register_member_api: the HTTP entry point for register_member_v1.
////
//// Pure, like every entry point here -- no cowboy, no mesh. The member
//// id is minted when the operator does not bring one; the event echoes it
//// back.

import gleam/dict
import gleam/dynamic
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/payload.{atom, type Payload}
import mcl_bookclub_gleam/host_bookclub/register_member/maybe_register_member
import mcl_bookclub_gleam/host_bookclub/register_member/register_member_v1

/// Params arrive atom-keyed (the facade JSON-decodes with atom labels). A
/// missing member_id is minted; the event echoes it back.
pub fn handle(params: Payload) -> desk.DispatchResult {
  let member_id = case desk.get_string(params, "member_id") {
    Ok("") -> register_member_v1.mint_member_id()
    Ok(id) -> id
    Error(_) -> register_member_v1.mint_member_id()
  }
  let params =
    dict.insert(params, atom("member_id"), dynamic.string(member_id))
  case register_member_v1.new(params) {
    Ok(command) -> maybe_register_member.dispatch(command)
    Error(e) -> Error(e)
  }
}
