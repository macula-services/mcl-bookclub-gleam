//// The plan_party policy: every fifth member registration plans a club
//// party.
////
//// The policy is an evoq_event_handler with a counter in its own state --
//// the shape the house rules give a cross-aggregate reaction that has no
//// per-process instance to correlate.
////
//// WHY THE HANDLER IS DRIVEN DIRECTLY, not through the subscription: the
//// suite shares ONE VM and ONE store, and evoq backfills a late-registered
//// handler the event type's history as live deliveries -- in a shared VM
//// that reorders other suites' registrations into this handler's counter,
//// so "the fifth registration" is not deterministic. (The Erlang twin
//// never saw this: its eunit runs the policy suite before any registering
//// suite.) The subscription -> handler wiring itself is covered by the
//// PRJ division's subscription_delivery_test; here the policy's RULE and
//// its real dispatch path (plan_party_v1 onto the club's stream) are
//// exercised directly, deterministically.

import gleam/dict
import gleam/dynamic
import gleam/list
import gleeunit/should
import mcl_bookclub_gleam/host_bookclub/initiate_bookclub/initiate_bookclub_api
import mcl_bookclub_gleam/host_bookclub/on_member_registered_v1_maybe_plan_party
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/payload.{type Payload, atom}
import mcl_bookclub_gleam/test_support

/// Initiate a club through the real entry point and return its id.
fn initiated_club() -> String {
  let params =
    dict.from_list([
      #(atom("name"), dynamic.string("The Crooked Shelf")),
      #(atom("initiated_by"), dynamic.string("bea")),
    ])
  let assert Ok(#(0, [event])) = initiate_bookclub_api.handle(params)
  let assert Ok(club_id) = desk.get_string(event, "club_id")
  club_id
}

/// A fabricated member_registered_v1 envelope for the club, the shape the
/// subscription would deliver.
fn registration(club_id: String) -> Payload {
  dict.from_list([
    #(atom("event_type"), dynamic.string("member_registered_v1")),
    #(atom("member_id"), dynamic.string("member-direct")),
    #(atom("club_id"), dynamic.string(club_id)),
    #(atom("name"), dynamic.string("Bea")),
    #(atom("registered_at"), dynamic.int(1000)),
  ])
}

/// Drive the policy's handle_event directly: each registration folds the
/// counter, and the fifth dispatches plan_party_v1 for the club the fifth
/// event names.
fn handle(
  club_id: String,
  state: on_member_registered_v1_maybe_plan_party.PartyPolicyState,
) {
  on_member_registered_v1_maybe_plan_party.handle_event(
    "member_registered_v1",
    registration(club_id),
    dict.new(),
    state,
  )
}

/// How many party_planned_v1 events the club's stream carries.
fn party_count(club_id: String) -> Int {
  test_support.read_stream(test_support.store_id(), club_id)
  |> list.fold(0, fn(count, pair) {
    case pair {
      #("party_planned_v1", _) -> count + 1
      _ -> count
    }
  })
}

pub fn every_fifth_registration_plans_a_party_test() {
  test_support.run(fn() {
    let club_id = initiated_club()
    let init = on_member_registered_v1_maybe_plan_party.PartyPolicyState(0)
    let assert Ok(one) = handle(club_id, init)
    let assert Ok(two) = handle(club_id, one)
    let assert Ok(three) = handle(club_id, two)
    let assert Ok(four) = handle(club_id, three)
    // Four registrations plan nothing.
    party_count(club_id) |> should.equal(0)
    // The fifth is the party cadence: the dispatch goes through the real
    // evoq path onto the club's stream.
    let assert Ok(_) = handle(club_id, four)
    party_count(club_id) |> should.equal(1)
    let assert [first_party, ..] =
      test_support.read_stream(test_support.store_id(), club_id)
      |> list.filter_map(fn(pair) {
        case pair {
          #("party_planned_v1", data) -> Ok(data)
          _ -> Error(Nil)
        }
      })
    let assert Ok(data_map) = desk.decode_map(first_party)
    desk.get_int(data_map, "parties_planned") |> should.equal(Ok(1))
  })
}
