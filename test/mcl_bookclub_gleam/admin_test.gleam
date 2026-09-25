//// The LAN admin UI's dispatch table, without the listener: fabricated
//// requests through admin.dispatch -- the same route the cowboy handler
//// uses. Writes go through the desk entry points against a real
//// reckon-db store (test_support.run); reads come back from the sqlite
//// read model through the bookclub_initiated projection, awaited like
//// the Erlang twin's careful client (see mcl_bookclub_admin_tests.erl).

import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/int
import gleeunit/should
import mcl_bookclub_gleam/admin
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/evoq
import mcl_bookclub_gleam/internal/payload.{atom, new, wrap}
import mcl_bookclub_gleam/project_bookclub/bookclub_read_model_store
import mcl_bookclub_gleam/query_bookclub/bookclub_query_store
import mcl_bookclub_gleam/query_bookclub/get_bookclub_by_id/get_bookclub_by_id
import mcl_bookclub_gleam/test_support

/// Start both division stores on one unique file. A start failure (the
/// registered name is taken by an earlier suite's store) is ignored: the
/// pair then answers through the already-running processes.
fn start_stores() -> Nil {
  let dir =
    "/tmp/mcl_bookclub_gleam_tests/admin_"
    <> int.to_string(test_support.unique_integer([wrap(atom("positive"))]))
  let path = dir <> "/bookclub.sqlite3"
  let _ = bookclub_read_model_store.start(path)
  let _ = bookclub_query_store.start(path)
  Nil
}

/// The club projection, the handler that puts an initiated club into the
/// read model the GETs and the enrichment read. Started per test; a
/// second instance for the same event type is idempotent (INSERT OR
/// REPLACE).
fn start_club_projection() -> Nil {
  let _ =
    evoq.start_handler(
      atom(
        "mcl_bookclub_gleam@project_bookclub@bookclub_initiated@bookclub_initiated_v1_to_sqlite_clubs",
      ),
      new(),
    )
  Nil
}

/// Await the projection's row, exactly as the Erlang twin's careful
/// client does: the read model is eventually consistent.
fn await_club(club_id: String, tries: Int) -> Bool {
  case get_bookclub_by_id.find(club_id) {
    Ok(_) -> True
    Error(_) ->
      case tries {
        0 -> False
        _ -> {
          process.sleep(100)
          await_club(club_id, tries - 1)
        }
      }
  }
}

fn initiate(name: String, by: String) -> #(Int, dynamic.Dynamic) {
  admin.dispatch(
    "POST",
    ["clubs", "initiate"],
    dict.from_list([
      #(atom("name"), dynamic.string(name)),
      #(atom("initiated_by"), dynamic.string(by)),
    ]),
  )
}

/// The club id the initiate event echoes back.
fn club_id_of(body: dynamic.Dynamic) -> String {
  let assert Ok(club_id) = first_event_of(body) |> desk.get_string("club_id")
  club_id
}

/// The first event map of a 200 body's `events' list.
fn first_event_of(
  body: dynamic.Dynamic,
) -> dict.Dict(dynamic.Dynamic, dynamic.Dynamic) {
  let assert Ok(body_map) = desk.decode_map(body)
  let assert Ok(events) = desk.get(body_map, "events")
  let assert Ok(event_list) = decode.run(events, decode.list(decode.dynamic))
  let assert [first_event, ..] = event_list
  let assert Ok(first_map) = desk.decode_map(first_event)
  first_map
}

pub fn the_admin_initiates_a_club_test() {
  test_support.run(fn() {
    start_stores()
    start_club_projection()
    let assert #(200, body) = initiate("Club", "raf")
    let assert Ok(body_map) = desk.decode_map(body)
    desk.get(body_map, "ok")
    |> should.equal(Ok(dynamic.bool(True)))
    desk.get_int(body_map, "version")
    |> should.equal(Ok(0))
    let club_id = club_id_of(body)
    let assert True = await_club(club_id, 50)
    let assert #(200, got_body) =
      admin.dispatch("GET", ["clubs", club_id], dict.new())
    let assert Ok(got_map) = desk.decode_map(got_body)
    desk.get_string(got_map, "name")
    |> should.equal(Ok("Club"))
    desk.get_string(got_map, "status")
    |> should.equal(Ok("active"))
  })
}

pub fn the_admin_enriches_the_club_name_test() {
  test_support.run(fn() {
    start_stores()
    start_club_projection()
    let assert #(200, body) = initiate("The Reading Circle", "raf")
    let club_id = club_id_of(body)
    let assert True = await_club(club_id, 50)
    // The entry point stamps the club's NAME into the command, so the
    // event -- and the fact a consumer receives -- says which club.
    let assert #(200, member_body) =
      admin.dispatch(
        "POST",
        ["members", "register"],
        dict.from_list([
          #(atom("club_id"), dynamic.string(club_id)),
          #(atom("name"), dynamic.string("Bea")),
        ]),
      )
    first_event_of(member_body)
    |> desk.get_string("club_name")
    |> should.equal(Ok("The Reading Circle"))
    // An explicit club_name round-trips untouched.
    let assert #(200, explicit_body) =
      admin.dispatch(
        "POST",
        ["members", "register"],
        dict.from_list([
          #(atom("club_id"), dynamic.string(club_id)),
          #(atom("name"), dynamic.string("Kim")),
          #(atom("club_name"), dynamic.string("Overridden")),
        ]),
      )
    first_event_of(explicit_body)
    |> desk.get_string("club_name")
    |> should.equal(Ok("Overridden"))
  })
}

pub fn the_admin_refuses_unknown_routes_test() {
  test_support.run(fn() {
    start_stores()
    let assert #(404, _) = admin.dispatch("GET", ["nope"], dict.new())
    let assert #(404, _) =
      admin.dispatch("POST", ["clubs", "bogus"], dict.new())
    Nil
  })
}

pub fn the_admin_reports_desk_refusals_test() {
  test_support.run(fn() {
    start_stores()
    let assert #(200, body) = initiate("Club", "raf")
    let club_id = club_id_of(body)
    let assert #(400, refused) =
      admin.dispatch(
        "POST",
        ["clubs", "initiate"],
        dict.from_list([
          #(atom("club_id"), dynamic.string(club_id)),
          #(atom("name"), dynamic.string("Club")),
          #(atom("initiated_by"), dynamic.string("raf")),
        ]),
      )
    let assert Ok(refused_map) = desk.decode_map(refused)
    desk.get(refused_map, "error")
    |> should.equal(Ok(atom("already_initiated")))
  })
}

/// Pure: no reckon store, no seeded row -- the read model simply has no
/// such club, and that is a 404, not a crash.
pub fn the_admin_reads_a_missing_id_as_missing_test() {
  start_stores()
  let assert #(404, _) =
    admin.dispatch("GET", ["clubs", "unknown-id"], dict.new())
  Nil
}
