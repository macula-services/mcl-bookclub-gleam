//// The mesh face of get_bookclub_by_id, without the mesh: the handler
//// reads the wire parameter (atom or binary key, plain or CBOR-text
//// value -- Demon 65), the QRY desk answers from the sqlite read model,
//// and the reply's text goes back out as CBOR text. The row is seeded
//// the way the PRJ tests seed it: through the read model store's own
//// exec, on a file both division stores share.

import gleam/dict
import gleam/dynamic
import gleam/int
import gleeunit/should
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/ids
import mcl_bookclub_gleam/internal/payload.{atom, wrap}
import mcl_bookclub_gleam/project_bookclub/bookclub_read_model_store
import mcl_bookclub_gleam/query_bookclub/bookclub_query_store
import mcl_bookclub_gleam/facts
import mcl_bookclub_gleam/get_bookclub_by_id
import mcl_bookclub_gleam/test_support

/// Start both division stores on one unique file. A start failure (the
/// registered name is taken by an earlier suite's store) is ignored: the
/// pair then answers through the already-running processes, which share
/// one file of their own.
fn start_stores() -> Nil {
  let dir =
    "/tmp/mcl_bookclub_gleam_tests/get_club_"
    <> int.to_string(test_support.unique_integer([wrap(atom("positive"))]))
  let path = dir <> "/bookclub.sqlite3"
  let _ = bookclub_read_model_store.start(path)
  let _ = bookclub_query_store.start(path)
  Nil
}

/// The club row the QRY desk selects, in the PRJ division's column order.
fn seed_club(club_id: String) -> Nil {
  let assert Ok(_) =
    bookclub_read_model_store.exec(
      "INSERT INTO clubs (club_id, name, status, initiated_by, initiated_at, event_id, version)"
      <> " VALUES (?, ?, ?, ?, ?, ?, ?)",
      [
        dynamic.string(club_id),
        dynamic.string("The Club"),
        dynamic.string("active"),
        dynamic.string("raf"),
        dynamic.int(1000),
        dynamic.string("evt-1"),
        dynamic.int(0),
      ],
    )
  Nil
}

/// The reply the handler must produce: {reply, Wire, undefined}, the
/// club's values wire-shaped (text as CBOR text, numbers as they are).
fn expected_reply(club_id: String) -> dynamic.Dynamic {
  let club_payload =
    dict.from_list([
      #(atom("club_id"), dynamic.string(club_id)),
      #(atom("name"), dynamic.string("The Club")),
      #(atom("status"), dynamic.string("active")),
      #(atom("initiated_by"), dynamic.string("raf")),
      #(atom("initiated_at"), dynamic.int(1000)),
    ])
  wrap(#(
    atom("reply"),
    desk.payload_to_dynamic(dict.map_values(club_payload, fn(_key, value) {
      facts.to_wire(value)
    })),
    atom("undefined"),
  ))
}

pub fn the_handler_answers_reply_for_a_known_club_test() {
  start_stores()
  let club_id = ids.mint_stream_id("bookclub")
  seed_club(club_id)
  get_bookclub_by_id.handle_request(
    dict.from_list([#(atom("club_id"), dynamic.string(club_id))]),
    atom("undefined"),
  )
  |> should.equal(expected_reply(club_id))
}

pub fn the_handler_answers_error_for_an_unknown_club_test() {
  start_stores()
  let unknown_id = ids.mint_stream_id("bookclub")
  get_bookclub_by_id.handle_request(
    dict.from_list([#(atom("club_id"), dynamic.string(unknown_id))]),
    atom("undefined"),
  )
  |> should.equal(wrap(#(atom("error"), atom("not_found"), atom("undefined"))))
}

/// Demon 65: the wire delivers both a binary key with a plain binary
/// value and a CBOR-text-wrapped value -- mcl_om_wire:field/2 resolves
/// either, so both must still reply.
pub fn the_handler_reads_binary_and_text_keys_test() {
  start_stores()
  let club_id = ids.mint_stream_id("bookclub")
  seed_club(club_id)
  // A binary key with a plain binary value.
  get_bookclub_by_id.handle_request(
    dict.from_list([#(dynamic.string("club_id"), dynamic.string(club_id))]),
    atom("undefined"),
  )
  |> should.equal(expected_reply(club_id))
  // An atom key whose value arrives CBOR-text-wrapped.
  get_bookclub_by_id.handle_request(
    dict.from_list([#(atom("club_id"), wrap(#(atom("text"), dynamic.string(club_id))))]),
    atom("undefined"),
  )
  |> should.equal(expected_reply(club_id))
}
