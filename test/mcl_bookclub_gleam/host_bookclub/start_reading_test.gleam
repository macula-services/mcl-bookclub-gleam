//// start_reading against a real reckon-db store through evoq.
////
//// The reading is the child aggregate: the reading id is minted on the
//// member's side, the reading initiates itself with its own birth event,
//// and the started event carries the member and the book being read.

import gleam/dict
import gleam/dynamic
import gleam/result
import gleeunit/should
import mcl_bookclub_gleam/host_bookclub/initiate_bookclub/initiate_bookclub_api
import mcl_bookclub_gleam/host_bookclub/register_member/register_member_api
import mcl_bookclub_gleam/host_bookclub/register_member/register_member_v1
import mcl_bookclub_gleam/host_bookclub/start_reading/maybe_start_reading
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

pub fn a_reading_starts_on_its_own_stream_test() {
  test_support.run(fn() {
    let club_id = initiated_club()
    let member_id = registered_member(club_id)
    let reading_id = start_reading_v1.mint_reading_id()
    let book_id = ids.mint_stream_id("book")
    let assert Ok(#(0, [event])) =
      start_reading_api.handle(
        dict.from_list([
          #(atom("reading_id"), dynamic.string(reading_id)),
          #(atom("member_id"), dynamic.string(member_id)),
          #(atom("book_id"), dynamic.string(book_id)),
        ]),
      )
    desk.get_string(event, "member_id") |> should.equal(Ok(member_id))
    desk.get_string(event, "book_id") |> should.equal(Ok(book_id))
    let stream = test_support.read_stream(test_support.store_id(), reading_id)
    let assert [#("reading_started_v1", _), ..] = stream
    Nil
  })
}

pub fn a_second_start_is_refused_test() {
  test_support.run(fn() {
    let club_id = initiated_club()
    let member_id = registered_member(club_id)
    let reading_id = start_reading_v1.mint_reading_id()
    let book_id = ids.mint_stream_id("book")
    let assert Ok(command) =
      start_reading_v1.new(
        dict.from_list([
          #(atom("reading_id"), dynamic.string(reading_id)),
          #(atom("member_id"), dynamic.string(member_id)),
          #(atom("book_id"), dynamic.string(book_id)),
        ]),
      )
    let assert Ok(_) = maybe_start_reading.dispatch(command)
    maybe_start_reading.dispatch(command)
    |> should.equal(Error(atom("already_started")))
  })
}

/// Demon 67: the desk validates BEFORE dispatch, so a rejected stream id
/// never touches the store.
pub fn a_rejected_stream_id_never_touches_the_store_test() {
  test_support.run(fn() {
    let assert Ok(command) =
      start_reading_v1.new(
        dict.from_list([
          #(atom("reading_id"), dynamic.string("nope")),
          #(
            atom("member_id"),
            dynamic.string(register_member_v1.mint_member_id()),
          ),
          #(atom("book_id"), dynamic.string(ids.mint_stream_id("book"))),
        ]),
      )
    let assert Error(_) = maybe_start_reading.dispatch(command)
    Nil
  })
}

pub fn a_command_needs_every_field_test() {
  start_reading_v1.new(dict.new())
  |> should.equal(Error(desk.missing_required_fields()))
}
