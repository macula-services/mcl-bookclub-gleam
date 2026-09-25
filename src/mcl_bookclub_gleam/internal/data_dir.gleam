//// The service's data dir: one env var, three consumers (the reckon-db
//// store via the service's data_dir/0 CHARLIST, and the two sqlite stores'
//// paths). The defaults are pinned together by a facade test so they
//// cannot drift.

import gleam/dynamic
import gleam/erlang/charlist
import mcl_bookclub_gleam/internal/payload.{atom, wrap}

/// os:getenv -- false (the atom) when unset.
@external(erlang, "os", "getenv")
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
/// service's data_dir/0 must return a charlist, never a String.
pub fn data_dir_charlist() -> dynamic.Dynamic {
  wrap(charlist.from_string(data_dir()))
}

/// The ok atom mcl_om's contract callbacks answer with.
pub fn ok_atom() -> dynamic.Dynamic {
  atom("ok")
}
