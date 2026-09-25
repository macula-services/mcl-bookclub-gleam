//// The esqlite edge: one connection per store actor, single statements.
////
//// A NIF connection belongs to the process that opened it, which is why
//// every write goes through the store actor that owns the connection.
//// Rows are LISTS of cells; SQL NULL maps to the atom `undefined`.

import gleam/dynamic
import mcl_bookclub_gleam/internal/payload.{atom}

/// esqlite3:open/1 -- {ok, Conn} | {error, Reason}. Reshaped by the FFI:
/// the NIF rejects a binary path and wants a charlist.
@external(erlang, "mcl_bookclub_gleam_ffi", "sqlite_open")
pub fn open(path: String) -> Result(dynamic.Dynamic, dynamic.Dynamic)

/// filelib:ensure_dir/1 -- make the sqlite file's directory exist.
/// Reshaped by the FFI (the Erlang side returns a bare `ok' atom).
@external(erlang, "mcl_bookclub_gleam_ffi", "ensure_dir")
pub fn ensure_dir(path: String) -> Result(Nil, dynamic.Dynamic)

/// One parameterised query, reshaped by the FFI: {ok, Rows} | {error, _}.
@external(erlang, "mcl_bookclub_gleam_ffi", "sqlite_q")
pub fn q(
  conn: dynamic.Dynamic,
  sql: String,
  args: List(dynamic.Dynamic),
) -> Result(List(List(dynamic.Dynamic)), dynamic.Dynamic)

/// One parameterised write: ok | {error, Reason}. A statement that returns
/// rows is a bug, surfaced as {unexpected_rows, _} -- the twins' policy.
@external(erlang, "mcl_bookclub_gleam_ffi", "sqlite_exec")
pub fn exec(
  conn: dynamic.Dynamic,
  sql: String,
  args: List(dynamic.Dynamic),
) -> Result(Nil, dynamic.Dynamic)

/// SQL NULL arrives as this atom.
pub fn sql_null() -> dynamic.Dynamic {
  atom("undefined")
}
