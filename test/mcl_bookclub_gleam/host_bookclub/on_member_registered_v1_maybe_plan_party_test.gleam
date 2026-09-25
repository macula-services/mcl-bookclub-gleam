//// The plan_party policy, end to end: member registrations flow through
//// the real $all subscription to the policy handler, and every fifth one
//// dispatches plan_party_v1 to the club's stream.
////
//// The policy is an evoq_event_handler with a counter in its own state --
//// the shape the house rules give a cross-aggregate reaction that has no
//// per-process instance to correlate. The counter persists across suite
//// runs in one VM, so this single test registers 4 then 1: self-contained.

import gleam/dict
import gleam/dynamic
import gleam/erlang/process
import gleam/list
import gleeunit/should
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/evoq
import mcl_bookclub_gleam/internal/payload.{atom, new}
import mcl_bookclub_gleam/test_support
import mcl_bookclub_gleam/host_bookclub/initiate_bookclub/initiate_bookclub_api
import mcl_bookclub_gleam/host_bookclub/register_member/register_member_api
import mcl_bookclub_gleam/host_bookclub/register_member/register_member_v1

const policy_module =
  "mcl_bookclub_gleam@host_bookclub@on_member_registered_v1_maybe_plan_party"

/// Initiate a club through the real entry point and return its id.
fn initiated_club() -> String {
  let params = dict.from_list([
    #(atom("name"), dynamic.string("The Crooked Shelf")),
    #(atom("initiated_by"), dynamic.string("bea")),
  ])
  let assert Ok(#(0, [event])) = initiate_bookclub_api.handle(params)
  desk.get_string(event, "club_id")
  |> should.be_ok
  let assert Ok(club_id) = desk.get_string(event, "club_id")
  club_id
}

/// Register a member against the club through the real entry point; the
/// member's stream id is minted, never derived from the name.
fn register_member(club_id: String) -> Nil {
  let params = dict.from_list([
    #(atom("member_id"), dynamic.string(register_member_v1.mint_member_id())),
    #(atom("club_id"), dynamic.string(club_id)),
    #(atom("name"), dynamic.string("Bea")),
  ])
  let assert Ok(_) = register_member_api.handle(params)
  Nil
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

/// The party_planned_v1 data maps on the club's stream.
fn parties_on(club_id: String) -> List(dynamic.Dynamic) {
  test_support.read_stream(test_support.store_id(), club_id)
  |> list.filter_map(fn(pair) {
    case pair {
      #("party_planned_v1", data) -> Ok(data)
      _ -> Error(Nil)
    }
  })
}

/// Poll the club's stream until the policy's plan_party dispatch lands --
/// the policy reacts asynchronously through the subscription, so the test
/// waits for the event instead of sleeping a fixed amount.
fn await_party(club_id: String, tries: Int) -> dynamic.Dynamic {
  case parties_on(club_id) {
    [first, ..] -> first
    [] if tries > 0 -> {
      process.sleep(100)
      await_party(club_id, tries - 1)
    }
    [] -> panic as "no party planned"
  }
}

pub fn every_fifth_registration_plans_a_party_test() {
  test_support.run(fn() {
    // Start the policy handler once, idempotently: a previous suite run in
    // this VM may already have it running. NOTE the shared-VM caveat:
    // evoq backfills a late-registered handler the event type's HISTORY as
    // live deliveries, so this handler's counter may start from another
    // suite's registrations -- the counter is best-effort entertainment,
    // not a business invariant. The assertion below is therefore the
    // phase-robust one: five consecutive registrations for THIS club
    // cross the every-fifth boundary exactly once, so exactly one party
    // lands on this club's stream.
    let _ = evoq.handler_start(atom(policy_module), new())
    let club_id = initiated_club()
    register_member(club_id)
    register_member(club_id)
    register_member(club_id)
    register_member(club_id)
    register_member(club_id)
    let party = await_party(club_id, 100)
    let assert Ok(data_map) = desk.decode_map(party)
    desk.get_int(data_map, "parties_planned") |> should.equal(Ok(1))
    party_count(club_id) |> should.equal(1)
  })
}
