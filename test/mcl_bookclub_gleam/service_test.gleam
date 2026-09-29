//// The service contract, asserted locally: the SAME names, procedure and
//// authority the Erlang and Phoenix twins advertise, so a peer cannot
//// tell the three clubs apart (the reference suite is
//// mcl_bookclub_service_tests.erl).
////
//// The store-backed tests start the divisions' sqlite stores the way the
//// PRJ/QRY suites do: a unique path per run, and a start failure (the
//// registered name is taken by an earlier suite's store) is ignored --
//// the calls then answer through the already-running processes.

import gleam/dynamic
import gleam/dynamic/decode
import gleam/int
import gleam/string
import gleeunit/should
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/evoq
import mcl_bookclub_gleam/internal/health
import mcl_bookclub_gleam/internal/payload.{atom, wrap}
import mcl_bookclub_gleam/internal/store
import mcl_bookclub_gleam/project_bookclub/bookclub_read_model_store
import mcl_bookclub_gleam/query_bookclub/bookclub_query_store
import mcl_bookclub_gleam/service
import mcl_bookclub_gleam/test_support

fn sqlite_path() -> String {
  "/tmp/mcl_bookclub_gleam_tests/service/"
  <> int.to_string(test_support.unique_integer([wrap(atom("positive"))]))
  <> "/bookclub.sqlite3"
}

/// The name a peer reads off /health is the repository's kebab-case
/// name, not the snake_case application atom.
pub fn the_info_names_the_shared_contract_test() {
  desk.get_string(service.info(), "name")
  |> should.equal(Ok("mcl-bookclub"))
}

/// The list is a promise that something answers: one procedure today,
/// the same procedure the twins advertise.
pub fn the_capabilities_are_the_one_procedure_test() {
  let assert [capability] = service.capabilities()
  desk.get_string(capability, "name")
  |> should.equal(Ok("get_bookclub_by_id"))
  desk.get_int(capability, "version")
  |> should.equal(Ok(1))
  desk.get(capability, "auth")
  |> should.equal(Ok(atom("open")))
}

/// One action per capability, one resource per published topic: the
/// authority asked for stays in step with what is announced.
pub fn the_identity_spec_matches_the_wire_contract_test() {
  let spec = service.identity_spec()
  desk.get_string(spec, "scope")
  |> should.equal(Ok("mcl-bookclub"))
  desk.get_int(spec, "ttl_days")
  |> should.equal(Ok(30))
  desk.get(spec, "actions")
  |> should.equal(Ok(dynamic.list([dynamic.string("get_bookclub_by_id")])))
  desk.get(spec, "resources")
  |> should.equal(
    Ok(
      dynamic.list([
        dynamic.string("bookclub/member/member_registered_v1"),
        dynamic.string("bookclub/book/book_procured_v1"),
        dynamic.string("bookclub/book/book_retired_v1"),
      ]),
    ),
  )
}

/// The store id is named in TWO places (the store app.gleam opens, and
/// evoq's dispatch opts) and nothing makes them agree by itself.
pub fn the_store_id_agrees_with_the_dispatch_opts_test() {
  store.id()
  |> should.equal(atom("mcl_bookclub_store"))
  store.id()
  |> should.equal(evoq.store_id_atom())
  evoq.store_id_atom()
  |> should.equal(atom("mcl_bookclub_store"))
  desk.get(evoq.dispatch_opts(), "store_id")
  |> should.equal(Ok(atom("mcl_bookclub_store")))
}

/// AND THE STORE ID IS IN A THIRD PLACE, the `evoq' block of the shipped
/// config. The test reads the template itself: a missing block is a
/// missing file, and nothing else would catch it.
pub fn the_store_id_agrees_with_the_sys_config_test() {
  let decoder = {
    use text <- decode.subfield([1], decode.string)
    decode.success(text)
  }
  let assert Ok(text) =
    decode.run(test_support.file_read("config/sys.config.src"), decoder)
  string.contains(text, "mcl_bookclub_store")
  |> should.be_true
}

/// The data dir the reckon-db store opens must be a REAL charlist --
/// dets/ra rejects a binary file option with {badarg, ...}.
pub fn the_data_dir_is_a_real_charlist_test() {
  let data_dir = store.dir()
  let assert Ok(_) = decode.run(data_dir, decode.list(decode.int))
  let assert Error(_) = decode.run(data_dir, decode.string)
  Nil
}

/// The service's health IS the health of its read path: ok with both
/// division stores up.
pub fn the_health_answers_ok_with_both_stores_test() {
  let path = sqlite_path()
  let _ = bookclub_read_model_store.start(path)
  let _ = bookclub_query_store.start(path)
  service.health()
  |> should.equal(atom("ok"))
}

/// A missing store answers honestly: {error, missing}, never a crash.
/// Deliberately no stores started here.
pub fn the_health_degrades_when_a_store_is_missing_test() {
  health.safe_ping(atom("definitely_not_a_store_name"), 50)
  |> should.be_error
}

/// THE STORE IS THIS SERVICE'S OWN (mcl_om opens none from 0.35, mcl-om#10):
/// app.gleam opens it after the division supervisors and before
/// mcl_om:boot/1, so the catch-up replay finds every projection listening.
pub fn the_store_is_opened_before_the_service_boots_test() {
  let decoder = {
    use text <- decode.subfield([1], decode.string)
    decode.success(text)
  }
  let assert Ok(app) =
    decode.run(
      test_support.file_read("src/mcl_bookclub_gleam/app.gleam"),
      decoder,
    )
  let assert Ok(#(before_boot, _)) = string.split_once(app, "mesh.boot(")
  string.contains(before_boot, "store.open()")
  |> should.be_true
}

/// NOT the old contract's names: mcl_om 0.35 warns at every boot about a
/// service module exporting store_id/0 and data_dir/0 together.
pub fn exports_none_of_the_old_store_callbacks_test() {
  ensure_loaded(atom("mcl_bookclub_gleam@service"))
  ["store_id", "data_dir", "store_indexes", "store_mode", "store_integrity"]
  |> list_exported
  |> should.equal([])
}

/// The applications the store needs are this service's to declare.
pub fn declares_the_store_applications_test() {
  let decoder = {
    use text <- decode.subfield([1], decode.string)
    decode.success(text)
  }
  let assert Ok(toml) =
    decode.run(test_support.file_read("gleam.toml"), decoder)
  ["reckon_db =", "evoq =", "reckon_evoq ="]
  |> list_missing(toml)
  |> should.equal([])
}

fn list_exported(names: List(String)) -> List(String) {
  case names {
    [] -> []
    [name, ..rest] ->
      case
        function_exported(atom("mcl_bookclub_gleam@service"), atom(name), 0)
      {
        True -> [name, ..list_exported(rest)]
        False -> list_exported(rest)
      }
  }
}

fn list_missing(needles: List(String), haystack: String) -> List(String) {
  case needles {
    [] -> []
    [needle, ..rest] ->
      case string.contains(haystack, needle) {
        True -> list_missing(rest, haystack)
        False -> [needle, ..list_missing(rest, haystack)]
      }
  }
}

@external(erlang, "code", "ensure_loaded")
fn ensure_loaded(module: dynamic.Dynamic) -> dynamic.Dynamic

@external(erlang, "erlang", "function_exported")
fn function_exported(
  module: dynamic.Dynamic,
  function: dynamic.Dynamic,
  arity: Int,
) -> Bool
