//// The service's data dir: one env var, three consumers (the reckon-db
//// store via the service's data_dir/0 CHARLIST, and the two sqlite stores'
//// paths). The defaults are pinned together by a facade test so they
//// cannot drift.

import gleam/dynamic
import mcl_bookclub_gleam/internal/payload.{atom, wrap}

/// os:getenv -- shaped by the FFI (a binary in, {ok, Binary} out; the
/// false atom arrives as Error(false)).
@external(erlang, "mcl_bookclub_gleam_ffi", "getenv")
pub fn getenv(name: String) -> Result(String, dynamic.Dynamic)

/// The data dir as a binary path, with the twins' default.
pub fn data_dir() -> String {
  case getenv("MCL_DATA_DIR") {
    Ok("") -> "/tmp/mcl_bookclub"
    Ok(path) -> path
    Error(_) -> "/tmp/mcl_bookclub"
  }
}

/// The sqlite read model path both division stores open.
pub fn sqlite_path() -> String {
  data_dir() <> "/bookclub.sqlite3"
}

/// The data dir as a CHARLIST -- dets/ra rejects binaries, so the
/// service's data_dir/0 must return a charlist, never a String. Note:
/// gleam_erlang's charlist module stores a BINARY; a real charlist comes
/// from the FFI's binary_to_list.
pub fn data_dir_charlist() -> dynamic.Dynamic {
  wrap(to_charlist(data_dir()))
}

@external(erlang, "mcl_bookclub_gleam_ffi", "bin_to_list")
fn to_charlist(binary: String) -> dynamic.Dynamic

/// The ok atom mcl_om's contract callbacks answer with.
pub fn ok_atom() -> dynamic.Dynamic {
  atom("ok")
}
