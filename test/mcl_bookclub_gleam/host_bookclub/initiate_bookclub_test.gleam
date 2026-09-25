//// initiate_bookclub against a real reckon-db store through evoq.
////
//// The store is opened by test_support with the same call the facade's
//// boot makes for this service, so the dispatch, the aggregate, the event
//// and its stream are the ones a running node has. The CMD division
//// touches no mesh code -- not even in tests.

import gleam/dict
import gleam/dynamic
import gleam/result
import gleeunit/should
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/ids
import mcl_bookclub_gleam/internal/payload.{atom}
import mcl_bookclub_gleam/test_support
import mcl_bookclub_gleam/host_bookclub/bookclub_state
import mcl_bookclub_gleam/host_bookclub/initiate_bookclub/initiate_bookclub_api
import mcl_bookclub_gleam/host_bookclub/initiate_bookclub/initiate_bookclub_v1
import mcl_bookclub_gleam/host_bookclub/initiate_bookclub/maybe_initiate_bookclub

/// The command the twins' tests club() builds: the club's stream id, its
/// name, and who initiated it.
fn club_command(
  club_id: String,
) -> Result(initiate_bookclub_v1.InitiateBookclub, dynamic.Dynamic) {
  initiate_bookclub_v1.new(dict.from_list([
    #(atom("club_id"), dynamic.string(club_id)),
    #(atom("name"), dynamic.string("The Crooked Shelf")),
    #(atom("initiated_by"), dynamic.string("bea")),
  ]))
}

pub fn a_club_is_initiated_on_its_own_stream_test() {
  test_support.run(fn() {
    // The api mints the club id when the operator does not bring one; the
    // event echoes it back.
    let params = dict.from_list([
      #(atom("name"), dynamic.string("The Crooked Shelf")),
      #(atom("initiated_by"), dynamic.string("bea")),
    ])
    let assert Ok(#(0, [event])) = initiate_bookclub_api.handle(params)
    desk.get_string(event, "name") |> should.equal(Ok("The Crooked Shelf"))
    desk.get_string(event, "initiated_by") |> should.equal(Ok("bea"))
    let club_id =
      desk.get_string(event, "club_id")
      |> result.unwrap("")
    // The stored stream carries the same event, the club's own id as its
    // stream id.
    let stream = test_support.read_stream(test_support.store_id(), club_id)
    let assert [#("bookclub_initiated_v1", data), ..] = stream
    let assert Ok(data_map) = desk.decode_map(data)
    desk.get_string(data_map, "name") |> should.equal(Ok("The Crooked Shelf"))
  })
}

/// The aggregate is the consistency boundary: the same club, asked twice,
/// is initiated once. The second dispatch's error IS the answer -- the
/// caller sees exactly this atom.
pub fn a_second_initiation_is_refused_test() {
  test_support.run(fn() {
    let assert Ok(command) = club_command(initiate_bookclub_v1.mint_club_id())
    let assert Ok(_) = maybe_initiate_bookclub.dispatch(command)
    maybe_initiate_bookclub.dispatch(command)
    |> should.equal(Error(atom("already_initiated")))
  })
}

/// Demon 67: the desk validates BEFORE dispatch, so a rejected stream id
/// never touches the store. The store client RAISES on a bad id, even just
/// reading it -- validation at the dispatch boundary is what prevents it.
pub fn a_rejected_stream_id_never_touches_the_store_test() {
  test_support.run(fn() {
    let assert Ok(command) = club_command("not-a-valid-id")
    let assert Error(_) = maybe_initiate_bookclub.dispatch(command)
    Nil
  })
}

pub fn a_command_needs_every_field_test() {
  initiate_bookclub_v1.new(dict.new())
  |> should.equal(Error(desk.missing_required_fields()))
  initiate_bookclub_v1.new(dict.from_list([
    #(atom("club_id"), dynamic.string("bookclub-x")),
    #(atom("name"), dynamic.string("")),
    #(atom("initiated_by"), dynamic.string("bea")),
  ]))
  |> should.equal(Error(desk.invalid_params()))
}

pub fn a_minted_club_id_satisfies_the_stream_contract_test() {
  ids.validate_stream_id(initiate_bookclub_v1.mint_club_id())
  |> should.equal(Ok(Nil))
}

/// evoq hands apply/2 two shapes for the same event: the raw event right
/// after execute/2 (business fields inline), and the stored envelope on
/// reload (business fields under `data'). A fold that matches one shape
/// only works in memory and silently no-ops on replay -- the bug shows on
/// the SECOND command, never the first.
pub fn the_state_folds_both_event_shapes_test() {
  let state =
    bookclub_state.new("club-1")
    |> bookclub_state.apply_event(dict.from_list([
      #(atom("event_type"), dynamic.string("bookclub_initiated_v1")),
      #(atom("name"), dynamic.string("Inline")),
      #(atom("initiated_by"), dynamic.string("bea")),
      #(atom("initiated_at"), dynamic.int(5)),
    ]))
  state |> bookclub_state.is_initiated |> should.be_true
  bookclub_state.name(state) |> should.equal("Inline")
  let state2 =
    bookclub_state.apply_event(state, dict.from_list([
      #(atom("event_type"), dynamic.string("bookclub_initiated_v1")),
      #(atom("data"), desk.payload_to_dynamic(dict.from_list([
        #(atom("name"), dynamic.string("Enveloped")),
        #(atom("initiated_by"), dynamic.string("bea")),
        #(atom("initiated_at"), dynamic.int(6)),
      ]))),
    ]))
  state2 |> bookclub_state.is_initiated |> should.be_true
  bookclub_state.name(state2) |> should.equal("Enveloped")
}

pub fn the_state_round_trips_through_a_map_test() {
  let state =
    bookclub_state.new("club-2")
    |> bookclub_state.apply_event(dict.from_list([
      #(atom("event_type"), dynamic.string("bookclub_initiated_v1")),
      #(atom("name"), dynamic.string("Round Trip")),
      #(atom("initiated_by"), dynamic.string("bea")),
      #(atom("initiated_at"), dynamic.int(7)),
    ]))
  let assert Ok(round_tripped) =
    state
    |> bookclub_state.to_map
    |> bookclub_state.from_map
  bookclub_state.name(round_tripped) |> should.equal("Round Trip")
  round_tripped |> bookclub_state.is_initiated |> should.be_true
  bookclub_state.initiated_at(round_tripped) |> should.equal(7)
}
