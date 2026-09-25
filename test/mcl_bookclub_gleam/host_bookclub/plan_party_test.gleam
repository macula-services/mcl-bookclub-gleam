//// plan_party against a real reckon-db store through evoq.
////
//// The count lives in the club's aggregate state, incremented there and
//// echoed into the event as the new absolute value -- a consumer folds the
//// count by assignment, never by increment.

import gleam/dict
import gleam/dynamic
import gleeunit/should
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/ids
import mcl_bookclub_gleam/internal/payload.{atom}
import mcl_bookclub_gleam/test_support
import mcl_bookclub_gleam/host_bookclub/bookclub_state
import mcl_bookclub_gleam/host_bookclub/archive_bookclub/archive_bookclub_api
import mcl_bookclub_gleam/host_bookclub/initiate_bookclub/initiate_bookclub_api
import mcl_bookclub_gleam/host_bookclub/plan_party/maybe_plan_party
import mcl_bookclub_gleam/host_bookclub/plan_party/plan_party_v1

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

/// The plan_party_v1 command names the club's stream id and nothing else.
fn plan_party(club_id: String) -> Result(plan_party_v1.PlanParty, dynamic.Dynamic) {
  plan_party_v1.new(dict.from_list([
    #(atom("club_id"), dynamic.string(club_id)),
  ]))
}

pub fn a_party_is_planned_with_the_incremented_count_test() {
  test_support.run(fn() {
    let club_id = initiated_club()
    // The initiation was the stream's version 0, so the first party is
    // version 1 and the second version 2 -- the event carries the club's
    // NEW absolute count, never a relative "+1".
    let assert Ok(first) = plan_party(club_id)
    let assert Ok(#(1, [event])) = maybe_plan_party.dispatch(first)
    desk.get_int(event, "parties_planned") |> should.equal(Ok(1))
    let assert Ok(second) = plan_party(club_id)
    let assert Ok(#(2, [event2])) = maybe_plan_party.dispatch(second)
    desk.get_int(event2, "parties_planned") |> should.equal(Ok(2))
    let stream = test_support.read_stream(test_support.store_id(), club_id)
    let assert [
      #("bookclub_initiated_v1", _),
      #("party_planned_v1", _),
      #("party_planned_v1", _),
    ] = stream
    Nil
  })
}

/// The desk's rule, distinct from the aggregate's blanket guard: a club
/// that was never initiated cannot plan a party.
pub fn a_party_for_an_uninitiated_club_is_refused_test() {
  test_support.run(fn() {
    let assert Ok(command) = plan_party(ids.mint_stream_id("bookclub"))
    maybe_plan_party.dispatch(command)
    |> should.equal(Error(atom("not_initiated")))
  })
}

/// The aggregate's blanket lifecycle guard owns this refusal, like every
/// other command on an archived stream.
pub fn a_party_for_an_archived_club_is_refused_test() {
  test_support.run(fn() {
    let club_id = initiated_club()
    let assert Ok(_) =
      archive_bookclub_api.handle(dict.from_list([
        #(atom("club_id"), dynamic.string(club_id)),
        #(atom("archived_by"), dynamic.string("raf")),
      ]))
    let assert Ok(command) = plan_party(club_id)
    maybe_plan_party.dispatch(command)
    |> should.equal(Error(atom("archived")))
  })
}

/// The fold is an absolute assignment: applying the same party event twice
/// still says 3.
pub fn the_state_folds_the_party_event_test() {
  let state =
    bookclub_state.new("club-3")
    |> bookclub_state.apply_event(dict.from_list([
      #(atom("event_type"), dynamic.string("bookclub_initiated_v1")),
      #(atom("name"), dynamic.string("N")),
      #(atom("initiated_by"), dynamic.string("bea")),
      #(atom("initiated_at"), dynamic.int(5)),
    ]))
  bookclub_state.parties_planned(state) |> should.equal(0)
  let state2 =
    bookclub_state.apply_event(state, dict.from_list([
      #(atom("event_type"), dynamic.string("party_planned_v1")),
      #(atom("parties_planned"), dynamic.int(3)),
    ]))
  bookclub_state.parties_planned(state2) |> should.equal(3)
  let state3 =
    bookclub_state.apply_event(state2, dict.from_list([
      #(atom("event_type"), dynamic.string("party_planned_v1")),
      #(atom("parties_planned"), dynamic.int(3)),
    ]))
  bookclub_state.parties_planned(state3) |> should.equal(3)
}
