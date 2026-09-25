//// archive_bookclub against a real reckon-db store through evoq.
////
//// The store is opened by test_support with the same call the facade's
//// boot makes for this service. The archived event is self-contained: it
//// echoes the club's birth details from the aggregate state, so its
//// projection can rebuild the whole row from this event alone.

import gleam/dict
import gleam/dynamic
import gleeunit/should
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/payload.{atom}
import mcl_bookclub_gleam/test_support
import mcl_bookclub_gleam/host_bookclub/bookclub_state
import mcl_bookclub_gleam/host_bookclub/archive_bookclub/archive_bookclub_api
import mcl_bookclub_gleam/host_bookclub/archive_bookclub/archive_bookclub_v1
import mcl_bookclub_gleam/host_bookclub/archive_bookclub/maybe_archive_bookclub
import mcl_bookclub_gleam/host_bookclub/initiate_bookclub/initiate_bookclub_api
import mcl_bookclub_gleam/host_bookclub/initiate_bookclub/initiate_bookclub_v1
import mcl_bookclub_gleam/host_bookclub/initiate_bookclub/maybe_initiate_bookclub

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

/// The archive_bookclub_v1 command names the club and who archived it.
fn archive(club_id: String) -> Result(archive_bookclub_v1.ArchiveBookclub, dynamic.Dynamic) {
  archive_bookclub_v1.new(dict.from_list([
    #(atom("club_id"), dynamic.string(club_id)),
    #(atom("archived_by"), dynamic.string("raf")),
  ]))
}

/// The archived event is self-contained: name and initiated_by echo the
/// aggregate state, and the stream's last event is the archive.
pub fn a_club_is_archived_test() {
  test_support.run(fn() {
    let club_id = initiated_club()
    let assert Ok(#(1, [event])) =
      archive_bookclub_api.handle(dict.from_list([
        #(atom("club_id"), dynamic.string(club_id)),
        #(atom("archived_by"), dynamic.string("raf")),
      ]))
    desk.get_string(event, "name") |> should.equal(Ok("The Crooked Shelf"))
    desk.get_string(event, "initiated_by") |> should.equal(Ok("bea"))
    desk.get_string(event, "archived_by") |> should.equal(Ok("raf"))
    let stream = test_support.read_stream(test_support.store_id(), club_id)
    let assert [#(_, _), #("bookclub_archived_v1", _)] = stream
    Nil
  })
}

/// The desk's rule, distinct from the aggregate's blanket guard: a club
/// that was never initiated cannot be archived either.
pub fn an_uninitiated_club_cannot_be_archived_test() {
  test_support.run(fn() {
    let assert Ok(command) = archive(initiate_bookclub_v1.mint_club_id())
    maybe_archive_bookclub.dispatch(command)
    |> should.equal(Error(atom("not_initiated")))
  })
}

/// The aggregate's blanket lifecycle guard: once archived, EVERY command on
/// the stream is refused -- even the one that would otherwise be fine.
pub fn an_archived_club_refuses_every_command_test() {
  test_support.run(fn() {
    let club_id = initiated_club()
    let assert Ok(_) =
      archive_bookclub_api.handle(dict.from_list([
        #(atom("club_id"), dynamic.string(club_id)),
        #(atom("archived_by"), dynamic.string("raf")),
      ]))
    let assert Ok(archive_again) = archive(club_id)
    maybe_archive_bookclub.dispatch(archive_again)
    |> should.equal(Error(atom("archived")))
    let assert Ok(initiate_again) =
      initiate_bookclub_v1.new(dict.from_list([
        #(atom("club_id"), dynamic.string(club_id)),
        #(atom("name"), dynamic.string("Again")),
        #(atom("initiated_by"), dynamic.string("bea")),
      ]))
    maybe_initiate_bookclub.dispatch(initiate_again)
    |> should.equal(Error(atom("archived")))
  })
}

/// The archive changes the flag, nothing else: the birth details survive
/// so a later event can still echo them.
pub fn the_state_folds_the_archive_event_test() {
  let state =
    bookclub_state.new("club-4")
    |> bookclub_state.apply_event(dict.from_list([
      #(atom("event_type"), dynamic.string("bookclub_initiated_v1")),
      #(atom("name"), dynamic.string("N")),
      #(atom("initiated_by"), dynamic.string("bea")),
      #(atom("initiated_at"), dynamic.int(5)),
    ]))
  state |> bookclub_state.is_archived |> should.be_false
  let state2 =
    bookclub_state.apply_event(state, dict.from_list([
      #(atom("event_type"), dynamic.string("bookclub_archived_v1")),
    ]))
  state2 |> bookclub_state.is_archived |> should.be_true
  state2 |> bookclub_state.is_initiated |> should.be_true
  bookclub_state.name(state2) |> should.equal("N")
  bookclub_state.initiated_by(state2) |> should.equal("bea")
  bookclub_state.initiated_at(state2) |> should.equal(5)
}
