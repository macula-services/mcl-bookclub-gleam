//// The test store: the reckon-db plumbing the twins reach through
//// -include_lib records, exposed through the FFI so Gleam tests never
//// build a #store_config{} tuple.
////
//// A test suite calls run/1: a fresh store dir, the evoq adapter env, the
//// store (single mode), and the evoq subscription -- the same wiring the
//// facade's boot makes. Desk tests dispatch real commands through evoq
//// against this store; the mesh is never touched.

import gleam/dynamic
import gleam/int
import gleam/list
import mcl_bookclub_gleam/internal/payload.{atom, wrap}

pub type TestStore {
  TestStore(dir: String)
}

@external(erlang, "mcl_bookclub_gleam_ffi", "bin_to_list")
fn to_charlist(binary: String) -> dynamic.Dynamic

@external(erlang, "mcl_bookclub_gleam_ffi", "test_set_evoq_env")
pub fn set_evoq_env(store_id: dynamic.Dynamic) -> Result(Nil, dynamic.Dynamic)

@external(erlang, "mcl_bookclub_gleam_ffi", "test_ensure_store")
pub fn ensure_store(
  store_id: dynamic.Dynamic,
  data_dir: dynamic.Dynamic,
) -> Result(Nil, dynamic.Dynamic)

@external(erlang, "mcl_bookclub_gleam_ffi", "test_start_subscription")
pub fn start_subscription(store_id: dynamic.Dynamic) -> Result(dynamic.Dynamic, dynamic.Dynamic)

@external(erlang, "mcl_bookclub_gleam_ffi", "test_read_stream")
pub fn read_stream(
  store_id: dynamic.Dynamic,
  stream_id: String,
) -> List(#(String, dynamic.Dynamic))

@external(erlang, "erlang", "unique_integer")
pub fn unique_integer(opts: List(dynamic.Dynamic)) -> Int

@external(erlang, "mcl_bookclub_gleam_ffi", "test_source_files")
pub fn source_files(dir: String) -> List(#(String, dynamic.Dynamic))

@external(erlang, "mcl_bookclub_gleam_ffi", "file_read")
pub fn file_read(path: String) -> dynamic.Dynamic

/// The store id every test addresses -- the same atom production uses.
pub fn store_id() -> dynamic.Dynamic {
  atom("mcl_bookclub_store")
}

/// Run a suite body against a fresh store. The dir is unique per run, so
/// suites can run in parallel; the store and subscription live for the
/// body's duration.
pub fn run(body: fn() -> Nil) -> Nil {
  let dir =
    "/tmp/mcl_bookclub_gleam_tests/" <> int.to_string(unique_integer([wrap(atom("positive"))]))
  let assert Ok(_) = set_evoq_env(store_id())
  let assert Ok(_) =
    ensure_store(store_id(), wrap(to_charlist(dir <> "/store")))
  let _ = start_subscription(store_id())
  let _ = dir
  body()
}

/// The source files of a division, for the boundary tests.
pub fn division_sources(division: String) -> List(String) {
  source_files("src/mcl_bookclub_gleam/" <> division)
  |> list.map(fn(pair) {
    let #(path, _content) = pair
    path
  })
}
