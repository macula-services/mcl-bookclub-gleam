//// Handler for `plan_party_v1'.
////
//// The desk: one module that owns the business rule (a party is planned
//// for an initiated club), produces the matching `party_planned_v1' event
//// with the incremented count echoed from state, and dispatches. The
//// aggregate calls handle_from_map/2; callers dispatch/1. The archived
//// refusal is the aggregate's blanket guard.

import gleam/dict
import gleam/dynamic
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/payload.{atom, type Payload}
import mcl_bookclub_gleam/host_bookclub/bookclub_state
import mcl_bookclub_gleam/host_bookclub/plan_party/party_planned_v1
import mcl_bookclub_gleam/host_bookclub/plan_party/plan_party_v1

/// The Erlang module atoms of this desk's own modules -- evoq addresses
/// the command by these.
pub const command_module = "mcl_bookclub_gleam@host_bookclub@plan_party@plan_party_v1"
pub const aggregate_module = "mcl_bookclub_gleam@host_bookclub@bookclub_aggregate"

/// The command's payload as evoq hands it to the aggregate: the map
/// plan_party_v1:to_map/1 made, atom-keyed.
pub fn handle_from_map(
  state: bookclub_state.BookclubState,
  payload: Payload,
) -> desk.DeskResult {
  case plan_party_v1.new(payload) {
    Ok(command) -> handle(state, command)
    Error(e) -> Error(e)
  }
}

/// The business rule: a party is planned only for an initiated club. The
/// count increments HERE, in the state the command runs against, and the
/// event carries the new count -- never a relative "+1" a consumer would
/// have to apply.
pub fn handle(
  state: bookclub_state.BookclubState,
  command: plan_party_v1.PlanParty,
) -> desk.DeskResult {
  case bookclub_state.is_initiated(state) {
    False -> Error(desk.error_atom("not_initiated"))
    True ->
      case plan_party_v1.validate(command) {
        Ok(_) -> events(state)
        Error(e) -> Error(e)
      }
  }
}

fn events(state: bookclub_state.BookclubState) -> desk.DeskResult {
  case party_planned_v1.new(dict.from_list([
    #(atom("club_id"), dynamic.string(bookclub_state.club_id(state))),
    #(atom("parties_planned"), dynamic.int(bookclub_state.parties_planned(state) + 1)),
  ])) {
    Ok(event) -> Ok([party_planned_v1.to_map(event)])
    Error(e) -> Error(e)
  }
}

/// Plan the party on the club's stream in the club's store. The caller
/// sees `Error(_)' rather than a success nothing stored.
///
/// VALIDATION HAPPENS HERE, BEFORE DISPATCH, AND THAT IS LOAD-BEARING:
/// the store client RAISES on a bad id, so the desk is the boundary -- it
/// validates, then dispatches (Demon 67).
pub fn dispatch(command: plan_party_v1.PlanParty) -> desk.DispatchResult {
  case plan_party_v1.validate(command) {
    Ok(_) ->
      desk.dispatch_command(
        command_module,
        aggregate_module,
        plan_party_v1.stream_id(command),
        plan_party_v1.to_map(command),
      )
    Error(e) -> Error(e)
  }
}
