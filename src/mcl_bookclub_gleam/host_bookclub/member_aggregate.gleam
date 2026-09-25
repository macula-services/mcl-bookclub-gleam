//// Aggregate root for a book-club member.
////
//// One stream per member, born by register_member_v1 and soft-deleted by
//// unregister_member_v1. Like the club, the aggregate owns a blanket
//// lifecycle guard: every command on an unregistered stream is refused
//// before any desk sees it. The member's stream id IS its identity,
//// minted by the caller with register_member_v1:mint_member_id/0.

import gleam/dynamic
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/payload.{atom, type Payload}
import mcl_bookclub_gleam/host_bookclub/member_state
import mcl_bookclub_gleam/host_bookclub/register_member/maybe_register_member
import mcl_bookclub_gleam/host_bookclub/unregister_member/maybe_unregister_member

/// The state module atom -- evoq resolves it by name.
pub fn state_module() -> dynamic.Dynamic {
  atom("mcl_bookclub_gleam@host_bookclub@member_state")
}

/// evoq calls init/1 when the stream's aggregate first starts.
pub fn init(aggregate_id: dynamic.Dynamic) -> Result(member_state.MemberState, dynamic.Dynamic) {
  case desk.string_from_dynamic(aggregate_id) {
    Ok(id) -> Ok(member_state.new(id))
    Error(e) -> Error(e)
  }
}

/// evoq calls execute(State, Payload) -- State FIRST. The guard rules live
/// in the desk's maybe_ module; the aggregate owns the stream's lifecycle.
pub fn execute(state: member_state.MemberState, payload: Payload) -> desk.DeskResult {
  case desk.command_is(payload, "register_member_v1") {
    True -> guarded(state, payload, maybe_register_member.handle_from_map)
    False ->
      case desk.command_is(payload, "unregister_member_v1") {
        True -> guarded(state, payload, maybe_unregister_member.handle_from_map)
        False -> Error(desk.unknown_command())
      }
  }
}

fn guarded(
  state: member_state.MemberState,
  payload: Payload,
  desk_fn: fn(member_state.MemberState, Payload) -> desk.DeskResult,
) -> desk.DeskResult {
  case member_state.is_unregistered(state) {
    True -> Error(desk.error_atom("unregistered"))
    False -> desk_fn(state, payload)
  }
}

pub fn apply(state: member_state.MemberState, event: Payload) -> member_state.MemberState {
  member_state.apply_event(state, event)
}

pub fn snapshot(state: member_state.MemberState) -> dynamic.Dynamic {
  desk.payload_to_dynamic(member_state.to_map(state))
}

pub fn from_snapshot(snapshot_data: dynamic.Dynamic) -> member_state.MemberState {
  let assert Ok(map) = desk.decode_map(snapshot_data)
  let assert Ok(state) = member_state.from_map(map)
  state
}
