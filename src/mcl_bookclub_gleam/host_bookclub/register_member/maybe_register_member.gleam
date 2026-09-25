//// Handler for `register_member_v1'.
////
//// The desk: one module that owns the business rule (a member registers
//// once), produces the matching `member_registered_v1' event, and
//// dispatches. The aggregate calls handle_from_map/2; callers dispatch/1.
//// The already-unregistered refusal is the aggregate's blanket guard, not
//// this desk's.

import gleam/dict
import gleam/dynamic
import mcl_bookclub_gleam/host_bookclub/member_state
import mcl_bookclub_gleam/host_bookclub/register_member/member_registered_v1
import mcl_bookclub_gleam/host_bookclub/register_member/register_member_v1
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/payload.{type Payload, atom}

/// The Erlang module atoms of this desk's own modules -- evoq addresses
/// the command by these.
pub const command_module = "mcl_bookclub_gleam@host_bookclub@register_member@register_member_v1"

pub const aggregate_module = "mcl_bookclub_gleam@host_bookclub@member_aggregate"

/// The command's payload as evoq hands it to the aggregate: the map
/// register_member_v1:to_map/1 made, atom-keyed.
pub fn handle_from_map(
  state: member_state.MemberState,
  payload: Payload,
) -> desk.DeskResult {
  case register_member_v1.new(payload) {
    Ok(command) -> handle(state, command)
    Error(e) -> Error(e)
  }
}

/// The business rule, stated against the aggregate state: a member
/// registers exactly once.
pub fn handle(
  state: member_state.MemberState,
  command: register_member_v1.RegisterMember,
) -> desk.DeskResult {
  case member_state.is_registered(state) {
    True -> Error(desk.error_atom("already_registered"))
    False ->
      case register_member_v1.validate(command) {
        Ok(_) -> events(command)
        Error(e) -> Error(e)
      }
  }
}

fn events(command: register_member_v1.RegisterMember) -> desk.DeskResult {
  case
    member_registered_v1.new(
      dict.from_list([
        #(
          atom("member_id"),
          dynamic.string(register_member_v1.get_member_id(command)),
        ),
        #(
          atom("club_id"),
          dynamic.string(register_member_v1.get_club_id(command)),
        ),
        #(atom("name"), dynamic.string(register_member_v1.get_name(command))),
        #(
          atom("club_name"),
          dynamic.string(register_member_v1.get_club_name(command)),
        ),
      ]),
    )
  {
    Ok(event) -> Ok([member_registered_v1.to_map(event)])
    Error(e) -> Error(e)
  }
}

/// Register the member on its own stream in the club's store. The caller
/// sees `Error(_)' rather than a success nothing stored.
///
/// VALIDATION HAPPENS HERE, BEFORE DISPATCH, AND THAT IS LOAD-BEARING:
/// the store client RAISES on a bad id, so the desk is the boundary -- it
/// validates, then dispatches (Demon 67).
pub fn dispatch(
  command: register_member_v1.RegisterMember,
) -> desk.DispatchResult {
  case register_member_v1.validate(command) {
    Ok(_) ->
      desk.dispatch_command(
        command_module,
        aggregate_module,
        register_member_v1.stream_id(command),
        register_member_v1.to_map(command),
      )
    Error(e) -> Error(e)
  }
}
