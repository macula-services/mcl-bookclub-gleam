//// Handler for `unregister_member_v1'.
////
//// The desk: one module that owns the business rule (a member unregisters
//// only once it exists), produces the matching `member_unregistered_v1'
//// event, and dispatches. The aggregate calls handle_from_map/2; callers
//// dispatch/1. The already-unregistered refusal is the aggregate's blanket
//// guard, not this desk's.

import gleam/dict
import gleam/dynamic
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/payload.{atom, type Payload}
import mcl_bookclub_gleam/host_bookclub/member_state
import mcl_bookclub_gleam/host_bookclub/unregister_member/member_unregistered_v1
import mcl_bookclub_gleam/host_bookclub/unregister_member/unregister_member_v1

/// The Erlang module atoms of this desk's own modules -- evoq addresses
/// the command by these.
pub const command_module = "mcl_bookclub_gleam@host_bookclub@unregister_member@unregister_member_v1"
pub const aggregate_module = "mcl_bookclub_gleam@host_bookclub@member_aggregate"

/// The command's payload as evoq hands it to the aggregate: the map
/// unregister_member_v1:to_map/1 made, atom-keyed.
pub fn handle_from_map(
  state: member_state.MemberState,
  payload: Payload,
) -> desk.DeskResult {
  case unregister_member_v1.new(payload) {
    Ok(command) -> handle(state, command)
    Error(e) -> Error(e)
  }
}

/// The business rule, stated against the aggregate state: a member can
/// only unregister once it exists.
pub fn handle(
  state: member_state.MemberState,
  command: unregister_member_v1.UnregisterMember,
) -> desk.DeskResult {
  case member_state.is_registered(state) {
    False -> Error(desk.error_atom("not_registered"))
    True ->
      case unregister_member_v1.validate(command) {
        Ok(_) -> events(state, command)
        Error(e) -> Error(e)
      }
  }
}

/// The event echoes the member's birth details from the aggregate state,
/// so the projection stays a self-sufficient absolute write.
fn events(
  state: member_state.MemberState,
  command: unregister_member_v1.UnregisterMember,
) -> desk.DeskResult {
  case member_unregistered_v1.new(dict.from_list([
    #(atom("member_id"), dynamic.string(member_state.member_id(state))),
    #(atom("club_id"), dynamic.string(member_state.club_id(state))),
    #(atom("name"), dynamic.string(member_state.name(state))),
    #(atom("registered_at"), dynamic.int(member_state.registered_at(state))),
    #(
      atom("unregistered_by"),
      dynamic.string(unregister_member_v1.get_unregistered_by(command)),
    ),
  ])) {
    Ok(event) -> Ok([member_unregistered_v1.to_map(event)])
    Error(e) -> Error(e)
  }
}

/// Unregister the member on its own stream in the club's store. The caller
/// sees `Error(_)' rather than a success nothing stored.
///
/// VALIDATION HAPPENS HERE, BEFORE DISPATCH, AND THAT IS LOAD-BEARING:
/// the store client RAISES on a bad id, so the desk is the boundary -- it
/// validates, then dispatches (Demon 67).
pub fn dispatch(command: unregister_member_v1.UnregisterMember) -> desk.DispatchResult {
  case unregister_member_v1.validate(command) {
    Ok(_) ->
      desk.dispatch_command(
        command_module,
        aggregate_module,
        unregister_member_v1.stream_id(command),
        unregister_member_v1.to_map(command),
      )
    Error(e) -> Error(e)
  }
}
