//// The test store: the reckon-db plumbing the twins reach through
//// -include_lib records, exposed through the FFI so Gleam tests never
//// build a #store_config{} tuple.
////
//// A test suite calls run/1: a fresh store dir, the evoq adapter env, the
//// store (single mode), the evoq subscription -- the same wiring the
//// facade's boot makes -- and a DELIVERY WARM-UP: canary commands are
//// dispatched until the store's notification emitter has provably
//// registered (a projected row appears), because the subscription's
//// subscribe races the store's async leader election and a lost race
//// drops delivery ("No emitters"). The warm-up makes every later test's
//// delivery deterministic. The mesh is never touched.

import gleam/dict
import gleam/dynamic
import gleam/erlang/process
import gleam/int
import gleam/list
import mcl_bookclub_gleam/host_bookclub/initiate_bookclub/initiate_bookclub_api
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/evoq
import mcl_bookclub_gleam/internal/payload.{atom, wrap}
import mcl_bookclub_gleam/project_bookclub/bookclub_read_model_store
import mcl_bookclub_gleam/query_bookclub/bookclub_query_store

pub type TestStore {
  TestStore(dir: String)
}

@external(erlang, "mcl_bookclub_gleam_ffi", "test_set_evoq_env")
pub fn set_evoq_env(store_id: dynamic.Dynamic) -> Result(Nil, dynamic.Dynamic)

/// Start the division apps, like the twins' test env's
/// application:ensure_all_started([reckon_db, evoq, reckon_evoq, esqlite])
/// -- and NOTHING else: the suite's VM must not carry the mesh-side apps,
/// whose processes widen the store's leader-election race at startup.
@external(erlang, "mcl_bookclub_gleam_ffi", "test_start_division_apps")
pub fn start_division_apps() -> Result(Nil, dynamic.Dynamic)

@external(erlang, "mcl_bookclub_gleam_ffi", "test_ensure_store")
pub fn ensure_store(
  store_id: dynamic.Dynamic,
  data_dir: dynamic.Dynamic,
) -> Result(Nil, dynamic.Dynamic)

@external(erlang, "mcl_bookclub_gleam_ffi", "test_start_subscription")
pub fn start_subscription(
  store_id: dynamic.Dynamic,
) -> Result(dynamic.Dynamic, dynamic.Dynamic)

@external(erlang, "mcl_bookclub_gleam_ffi", "test_read_stream")
pub fn read_stream(
  store_id: dynamic.Dynamic,
  stream_id: String,
) -> List(#(String, dynamic.Dynamic))

@external(erlang, "erlang", "unique_integer")
pub fn unique_integer(opts: List(dynamic.Dynamic)) -> Int

@external(erlang, "erlang", "system_time")
pub fn system_time_ms(unit: dynamic.Dynamic) -> Int

@external(erlang, "mcl_bookclub_gleam_ffi", "test_source_files")
pub fn source_files(dir: String) -> List(#(String, dynamic.Dynamic))

@external(erlang, "mcl_bookclub_gleam_ffi", "file_read")
pub fn file_read(path: String) -> dynamic.Dynamic

@external(erlang, "mcl_bookclub_gleam_ffi", "bin_to_list")
fn to_charlist(binary: String) -> dynamic.Dynamic

/// The store id every test addresses -- the same atom production uses.
pub fn store_id() -> dynamic.Dynamic {
  atom("mcl_bookclub_store")
}

const club_projection_module = "mcl_bookclub_gleam@project_bookclub@bookclub_initiated@bookclub_initiated_v1_to_sqlite_clubs"

/// Run a suite body against a fresh store. The dir is unique per run, so
/// suites can run in parallel; the store and subscription live for the
/// body's duration.
pub fn run(body: fn() -> Nil) -> Nil {
  // UNIQUE ACROSS RUNS, not just within one VM: unique_integer restarts
  // at 1 in every fresh VM, so a bare counter reopens a previous run's
  // leftover store under the same path -- the accumulating history then
  // delays the emitter registration and widens the startup race (the
  // "No emitters" drops). The wall clock makes the dir run-unique.
  let dir =
    "/tmp/mcl_bookclub_gleam_tests/"
    <> int.to_string(system_time_ms(atom("millisecond")))
    <> "_"
    <> int.to_string(unique_integer([wrap(atom("positive"))]))
  let assert Ok(_) = set_evoq_env(store_id())
  let assert Ok(_) = start_division_apps()
  let assert Ok(_) =
    ensure_store(store_id(), wrap(to_charlist(dir <> "/store")))
  case start_subscription(store_id()) {
    Ok(subscription) ->
      // A FRESH subscription needs its delivery proven before any real
      // dispatch: the canary warm-up below.
      case subscription == wrap(atom("started")) {
        True -> warm_up_delivery()
        False -> Nil
      }
    Error(_) -> Nil
  }
  let _ = dir
  body()
}

/// Dispatch canary commands until a projected row appears: the proof that
/// the store's notification emitter has registered and delivery works.
/// Races the same leader election the first real dispatch would; losing
/// here costs a throwaway club, not a test.
///
/// BOTH sqlite stores start here, on the warm-up's own path: whichever
/// test's ensure_stores runs next finds the names taken and quietly keeps
/// this consistent pair, so the read model and the queries always agree
/// on one file.
fn warm_up_delivery() -> Nil {
  let path = warm_up_path()
  let _ = bookclub_read_model_store.start(path)
  let _ = bookclub_query_store.start(path)
  let _ = evoq.handler_start(atom(club_projection_module), dict.new())
  warm_up_attempt(0)
}

fn warm_up_path() -> String {
  "/tmp/mcl_bookclub_gleam_tests/warmup_"
  <> int.to_string(unique_integer([wrap(atom("positive"))]))
  <> "/bookclub.sqlite3"
}

fn warm_up_attempt(attempt: Int) -> Nil {
  case attempt {
    10 -> Nil
    _ -> {
      let assert Ok(#(_, [event])) =
        initiate_bookclub_api.handle(
          dict.from_list([
            #(atom("name"), dynamic.string("warm-up club")),
            #(atom("initiated_by"), dynamic.string("test_support")),
          ]),
        )
      let assert Ok(club_id) = desk.get_string(event, "club_id")
      case warm_up_row(club_id, 10) {
        True -> Nil
        False -> {
          process.sleep(200)
          warm_up_attempt(attempt + 1)
        }
      }
    }
  }
}

fn warm_up_row(club_id: String, tries: Int) -> Bool {
  case
    bookclub_read_model_store.q("SELECT club_id FROM clubs WHERE club_id = ?", [
      dynamic.string(club_id),
    ])
  {
    Ok([_]) -> True
    _ ->
      case tries {
        0 -> False
        _ -> {
          process.sleep(100)
          warm_up_row(club_id, tries - 1)
        }
      }
  }
}

/// The source files of a division, for the boundary tests.
pub fn division_sources(division: String) -> List(String) {
  source_files("src/mcl_bookclub_gleam/" <> division)
  |> list.map(fn(pair) {
    let #(path, _content) = pair
    path
  })
}
