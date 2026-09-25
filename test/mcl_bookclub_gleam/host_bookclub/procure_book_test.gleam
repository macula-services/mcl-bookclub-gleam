//// procure_book against a real reckon-db store through evoq.
////
//// The store is opened by test_support with the same call the facade's
//// boot makes for this service.
//// The retire changes the flag, nothing else: the birth details survive
//// so a later event can still echo them.

import gleam/dict
import gleam/dynamic
import gleam/result
import gleeunit/should
import mcl_bookclub_gleam/host_bookclub/book_state
import mcl_bookclub_gleam/host_bookclub/initiate_bookclub/initiate_bookclub_api
import mcl_bookclub_gleam/host_bookclub/procure_book/maybe_procure_book
import mcl_bookclub_gleam/host_bookclub/procure_book/procure_book_api
import mcl_bookclub_gleam/host_bookclub/procure_book/procure_book_v1
import mcl_bookclub_gleam/internal/desk
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

/// A procure command for the club: a minted book id, the bibliographic
/// facts.
fn book(
  club_id: String,
) -> Result(procure_book_v1.ProcureBook, dynamic.Dynamic) {
  procure_book_v1.new(
    dict.from_list([
      #(atom("book_id"), dynamic.string(procure_book_v1.mint_book_id())),
      #(atom("club_id"), dynamic.string(club_id)),
      #(atom("title"), dynamic.string("Persuasion")),
      #(atom("author"), dynamic.string("Austen")),
    ]),
  )
}

pub fn a_book_is_procured_on_its_own_stream_test() {
  test_support.run(fn() {
    let club_id = initiated_club()
    let book_id = procure_book_v1.mint_book_id()
    let assert Ok(#(0, [event])) =
      procure_book_api.handle(
        dict.from_list([
          #(atom("book_id"), dynamic.string(book_id)),
          #(atom("club_id"), dynamic.string(club_id)),
          #(atom("title"), dynamic.string("Persuasion")),
          #(atom("author"), dynamic.string("Austen")),
        ]),
      )
    desk.get_string(event, "title") |> should.equal(Ok("Persuasion"))
    desk.get_string(event, "author") |> should.equal(Ok("Austen"))
    let stream = test_support.read_stream(test_support.store_id(), book_id)
    let assert [#("book_procured_v1", _), ..] = stream
    Nil
  })
}

pub fn a_second_procurement_is_refused_test() {
  test_support.run(fn() {
    let club_id = initiated_club()
    let assert Ok(command) = book(club_id)
    let assert Ok(_) = maybe_procure_book.dispatch(command)
    maybe_procure_book.dispatch(command)
    |> should.equal(Error(atom("already_procured")))
  })
}

/// Demon 67: the desk validates BEFORE dispatch, so a rejected stream id
/// never touches the store.
pub fn a_rejected_stream_id_never_touches_the_store_test() {
  test_support.run(fn() {
    let assert Ok(command) =
      procure_book_v1.new(
        dict.from_list([
          #(atom("book_id"), dynamic.string("not-valid")),
          #(atom("club_id"), dynamic.string(procure_book_v1.mint_book_id())),
          #(atom("title"), dynamic.string("Persuasion")),
          #(atom("author"), dynamic.string("Austen")),
        ]),
      )
    let assert Error(_) = maybe_procure_book.dispatch(command)
    Nil
  })
}

pub fn a_command_needs_every_field_test() {
  procure_book_v1.new(dict.new())
  |> should.equal(Error(desk.missing_required_fields()))
}

pub fn the_state_folds_both_events_test() {
  let state =
    book_state.new("b1")
    |> book_state.apply_event(
      dict.from_list([
        #(atom("event_type"), dynamic.string("book_procured_v1")),
        #(atom("club_id"), dynamic.string("club-a")),
        #(atom("title"), dynamic.string("Inline")),
        #(atom("author"), dynamic.string("Austen")),
        #(atom("procured_at"), dynamic.int(1000)),
      ]),
    )
  state |> book_state.is_on_shelf |> should.be_true
  let state2 =
    book_state.apply_event(
      state,
      dict.from_list([
        #(atom("event_type"), dynamic.string("book_retired_v1")),
      ]),
    )
  state2 |> book_state.is_retired |> should.be_true
  book_state.title(state2) |> should.equal("Inline")
  book_state.procured_at(state2) |> should.equal(1000)
}
