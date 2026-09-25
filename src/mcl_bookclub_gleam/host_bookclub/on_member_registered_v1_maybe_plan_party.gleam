//// Policy: every fifth member registration plans a club party.
////
//// A policy is a sibling slice of the target CMD app, reacting to a domain
//// event and dispatching a command to another aggregate -- here, from a
//// member's stream to the club's. It is an evoq_event_handler with its own
//// small state, NOT an evoq_process_manager: the rule has no per-process
//// instance to correlate.
////
//// TWO DELIBERATE CHOICES, each worth understanding before copying:
////
//// - replay_policy/0 is `skip': this handler's effect is a command
////   dispatch, and repeating it on replay would plan duplicate parties. A
////   handler with side effects must declare skip; a projection whose write
////   is idempotent declares deliver.
////
//// - The counter lives in the handler's in-memory state. A restart resets
////   it, so the party cadence is best-effort entertainment, not a business
////   invariant. The honest home for a durable counter is the club's own
////   stream (a tally event) -- the shape the corpus prefers for anything
////   that must survive a restart.

import gleam/dict
import gleam/dynamic
import mcl_bookclub_gleam/host_bookclub/plan_party/maybe_plan_party
import mcl_bookclub_gleam/host_bookclub/plan_party/plan_party_v1
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/evoq
import mcl_bookclub_gleam/internal/log
import mcl_bookclub_gleam/internal/payload.{type Payload, atom}

const party_every = 5

/// The handler's own state: the in-memory registration tally.
pub type PartyPolicyState {
  PartyPolicyState(registrations: Int)
}

pub fn interested_in() -> List(String) {
  ["member_registered_v1"]
}

pub fn replay_policy() -> dynamic.Dynamic {
  evoq.replay_skip()
}

pub fn init(_config: Payload) -> Result(PartyPolicyState, dynamic.Dynamic) {
  Ok(PartyPolicyState(registrations: 0))
}

pub fn handle_event(
  _event_type: String,
  event: Payload,
  _metadata: Payload,
  state: PartyPolicyState,
) -> Result(PartyPolicyState, dynamic.Dynamic) {
  let data = desk.event_data(event)
  let count = state.registrations + 1
  case count % party_every {
    0 -> plan_party(desk.get_string_default(data, "club_id", ""))
    _ -> Nil
  }
  Ok(PartyPolicyState(registrations: count))
}

/// The dispatch result is the only error channel. A party that cannot be
/// planned (an archived club, a race with archive) is logged, not thrown:
/// the policy must never take the delivery of every later event down with
/// it, and the club's own stream is the authority on whether a party
/// exists, not this handler.
fn plan_party(club_id: String) -> Nil {
  case
    plan_party_v1.new(
      dict.from_list([
        #(atom("club_id"), dynamic.string(club_id)),
      ]),
    )
  {
    Ok(command) ->
      case maybe_plan_party.dispatch(command) {
        Ok(_) -> Nil
        Error(reason) -> warn(plan_party_v1.stream_id(command), reason)
      }
    Error(reason) -> warn(club_id, reason)
  }
}

fn warn(club_id: String, reason: dynamic.Dynamic) -> Nil {
  log.warning(
    dict.from_list([
      #(atom("what"), atom("party_not_planned")),
      #(atom("club_id"), dynamic.string(club_id)),
      #(atom("reason"), reason),
    ]),
  )
}
