//// retire_book against a real reckon-db store through evoq.
////
//// The retired event is self-contained: it echoes the bibliographic
//// facts from the aggregate state, so its projection stays an absolute,
//// idempotent write.

import gleam/dict
import gleam/dynamic
import gleam/list
import gleam/result
import gleeunit/should
import mcl_bookclub_gleam/host_bookclub/initiate_bookclub/initiate_bookclub_api
import mcl_bookclub_gleam/host_bookclub/procure_book/maybe_procure_book
import mcl_bookclub_gleam/host_bookclub/procure_book/procure_book_api
import mcl_bookclub_gleam/host_bookclub/procure_book/procure_book_v1
import mcl_bookclub_gleam/host_bookclub/retire_book/maybe_retire_book
import mcl_bookclub_gleam/host_bookclub/retire_book/retire_book_api
import mcl_bookclub_gleam/host_bookclub/retire_book/retire_book_v1
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

pub fn a_book_is_retired_with_its_bibliographic_echo_test() {
  test_support.run(fn() {
    let club_id = initiated_club()
    let book_id = procure_book_v1.mint_book_id()
    let assert Ok(#(0, _)) =
      procure_book_api.handle(
        dict.from_list([
          #(atom("book_id"), dynamic.string(book_id)),
          #(atom("club_id"), dynamic.string(club_id)),
          #(atom("title"), dynamic.string("Persuasion")),
          #(atom("author"), dynamic.string("Austen")),
        ]),
      )
    let assert Ok(#(1, [event])) =
      retire_book_api.handle(
        dict.from_list([
          #(atom("book_id"), dynamic.string(book_id)),
          #(atom("retired_by"), dynamic.string("raf")),
        ]),
      )
    desk.get_string(event, "title") |> should.equal(Ok("Persuasion"))
    desk.get_string(event, "author") |> should.equal(Ok("Austen"))
    desk.get_string(event, "club_id") |> should.equal(Ok(club_id))
    desk.get_string(event, "retired_by") |> should.equal(Ok("raf"))
    desk.get_int(event, "procured_at") |> should.be_ok
    let stream = test_support.read_stream(test_support.store_id(), book_id)
    let assert [#("book_retired_v1", _), ..] = list.reverse(stream)
    Nil
  })
}

pub fn an_unprocured_book_cannot_be_retired_test() {
  test_support.run(fn() {
    retire_book_api.handle(
      dict.from_list([
        #(atom("book_id"), dynamic.string(procure_book_v1.mint_book_id())),
        #(atom("retired_by"), dynamic.string("raf")),
      ]),
    )
    |> should.equal(Error(atom("not_procured")))
  })
}

/// The aggregate's blanket lifecycle guard: once retired, EVERY command
/// on the stream is refused -- procuring again included.
pub fn a_retired_book_refuses_every_command_test() {
  test_support.run(fn() {
    let club_id = initiated_club()
    let assert Ok(command) =
      procure_book_v1.new(
        dict.from_list([
          #(atom("book_id"), dynamic.string(procure_book_v1.mint_book_id())),
          #(atom("club_id"), dynamic.string(club_id)),
          #(atom("title"), dynamic.string("Persuasion")),
          #(atom("author"), dynamic.string("Austen")),
        ]),
      )
    let assert Ok(_) = maybe_procure_book.dispatch(command)
    let book_id = procure_book_v1.stream_id(command)
    let assert Ok(retire) =
      retire_book_v1.new(
        dict.from_list([
          #(atom("book_id"), dynamic.string(book_id)),
          #(atom("retired_by"), dynamic.string("raf")),
        ]),
      )
    let assert Ok(_) = maybe_retire_book.dispatch(retire)
    maybe_procure_book.dispatch(command)
    |> should.equal(Error(atom("retired")))
  })
}
