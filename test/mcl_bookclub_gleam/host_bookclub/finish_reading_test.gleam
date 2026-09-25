//// finish_reading against a real reckon-db store through evoq.
////
//// The finished event echoes the fold -- member, book, start time -- so
//// its projection rebuilds the readings row from this event alone, and
//// takes the pages read from the command.
//// The finish changes the pages and the flag, nothing else: the fold
//// details survive for any later event to echo.

import gleam/dict
import gleam/dynamic
import gleam/list
import gleam/result
import gleeunit/should
import mcl_bookclub_gleam/host_bookclub/finish_reading/finish_reading_api
import mcl_bookclub_gleam/host_bookclub/finish_reading/finish_reading_v1
import mcl_bookclub_gleam/host_bookclub/finish_reading/maybe_finish_reading
import mcl_bookclub_gleam/host_bookclub/initiate_bookclub/initiate_bookclub_api
import mcl_bookclub_gleam/host_bookclub/reading_state
import mcl_bookclub_gleam/host_bookclub/register_member/register_member_api
import mcl_bookclub_gleam/host_bookclub/register_member/register_member_v1
import mcl_bookclub_gleam/host_bookclub/start_reading/start_reading_api
import mcl_bookclub_gleam/host_bookclub/start_reading/start_reading_v1
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/ids
import mcl_bookclub_gleam/internal/payload.{atom}
import mcl_bookclub_gleam/test_support

/// Initiate a club through the real entry point and return its id.
fn initiated_club() -> String {
  let params =
    dict.from_list([
      #(atom("name"), dynamic.string("The Reading Circle")),
      #(atom("initiated_by"), dynamic.string("raf")),
    ])
  let assert Ok(#(0, [event])) = initiate_bookclub_api.handle(params)
  desk.get_string(event, "club_id")
  |> result.unwrap("")
}

/// Register a member through the real entry point and return its id.
fn registered_member(club_id: String) -> String {
  let member_id = register_member_v1.mint_member_id()
  let assert Ok(#(0, [event])) =
    register_member_api.handle(
      dict.from_list([
        #(atom("member_id"), dynamic.string(member_id)),
        #(atom("club_id"), dynamic.string(club_id)),
        #(atom("name"), dynamic.string("Bea")),
      ]),
    )
  desk.get_string(event, "member_id")
  |> result.unwrap("")
}

/// Register a member and start a reading for them: the reading id, the
/// member id, and the book id of the started reading.
fn started_reading(club_id: String) -> #(String, String, String) {
  let member_id = registered_member(club_id)
  let reading_id = start_reading_v1.mint_reading_id()
  let book_id = ids.mint_stream_id("book")
  let assert Ok(#(0, _)) =
    start_reading_api.handle(
      dict.from_list([
        #(atom("reading_id"), dynamic.string(reading_id)),
        #(atom("member_id"), dynamic.string(member_id)),
        #(atom("book_id"), dynamic.string(book_id)),
      ]),
    )
  #(reading_id, member_id, book_id)
}

pub fn a_reading_finishes_with_the_state_echo_test() {
  test_support.run(fn() {
    let club_id = initiated_club()
    let #(reading_id, member_id, book_id) = started_reading(club_id)
    let assert Ok(#(1, [event])) =
      finish_reading_api.handle(
        dict.from_list([
          #(atom("reading_id"), dynamic.string(reading_id)),
          #(atom("pages_read"), dynamic.int(342)),
        ]),
      )
    desk.get_int(event, "pages_read") |> should.equal(Ok(342))
    desk.get_string(event, "member_id") |> should.equal(Ok(member_id))
    desk.get_string(event, "book_id") |> should.equal(Ok(book_id))
    desk.get_int(event, "started_at") |> should.be_ok
    let stream = test_support.read_stream(test_support.store_id(), reading_id)
    let assert [#("reading_finished_v1", _), ..] = list.reverse(stream)
    Nil
  })
}

pub fn an_unstarted_reading_cannot_finish_test() {
  test_support.run(fn() {
    finish_reading_api.handle(
      dict.from_list([
        #(
          atom("reading_id"),
          dynamic.string(start_reading_v1.mint_reading_id()),
        ),
        #(atom("pages_read"), dynamic.int(100)),
      ]),
    )
    |> should.equal(Error(atom("not_started")))
  })
}

/// The aggregate's blanket lifecycle guard: once finished, EVERY command
/// on the stream is refused -- finishing again included.
pub fn a_finished_reading_refuses_every_command_test() {
  test_support.run(fn() {
    let club_id = initiated_club()
    let #(reading_id, _, _) = started_reading(club_id)
    let assert Ok(finish) =
      finish_reading_v1.new(
        dict.from_list([
          #(atom("reading_id"), dynamic.string(reading_id)),
          #(atom("pages_read"), dynamic.int(100)),
        ]),
      )
    let assert Ok(_) = maybe_finish_reading.dispatch(finish)
    maybe_finish_reading.dispatch(finish)
    |> should.equal(Error(atom("finished")))
  })
}

pub fn the_pages_read_validation_test() {
  finish_reading_v1.new(
    dict.from_list([
      #(atom("reading_id"), dynamic.string(start_reading_v1.mint_reading_id())),
      #(atom("pages_read"), dynamic.int(-1)),
    ]),
  )
  |> should.equal(Error(desk.invalid_params()))
  finish_reading_v1.new(
    dict.from_list([
      #(atom("reading_id"), dynamic.string(start_reading_v1.mint_reading_id())),
    ]),
  )
  |> should.equal(Error(desk.missing_required_fields()))
}

pub fn the_state_folds_both_events_test() {
  let state =
    reading_state.new("r1")
    |> reading_state.apply_event(
      dict.from_list([
        #(atom("event_type"), dynamic.string("reading_started_v1")),
        #(atom("member_id"), dynamic.string("member-1")),
        #(atom("book_id"), dynamic.string("book-1")),
        #(atom("started_at"), dynamic.int(5)),
      ]),
    )
  state |> reading_state.is_in_progress |> should.be_true
  let state2 =
    reading_state.apply_event(
      state,
      dict.from_list([
        #(atom("event_type"), dynamic.string("reading_finished_v1")),
        #(atom("pages_read"), dynamic.int(476)),
      ]),
    )
  state2 |> reading_state.is_finished |> should.be_true
  reading_state.pages_read(state2) |> should.equal(476)
  reading_state.member_id(state2) |> should.equal("member-1")
  reading_state.book_id(state2) |> should.equal("book-1")
  reading_state.started_at(state2) |> should.equal(5)
}
