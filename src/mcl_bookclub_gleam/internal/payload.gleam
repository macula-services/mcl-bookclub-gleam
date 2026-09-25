//// A payload as it crosses the evoq/wire boundary: a map of dynamic keys
//// to dynamic values. The twins' payloads mix atom keys (fresh commands)
//// and binary keys (events read back from the store), so everything is
//// read tolerantly. Helpers for building dynamic values live here too:
//// gleam_stdlib 1.x dropped `dynamic.from/1` in favor of typed
//// constructors, so arbitrary terms (atoms, pids, tuples) go through the
//// FFI's identity wrapper.

import gleam/dict
import gleam/dynamic
import gleam/erlang/atom

pub type Payload =
  dict.Dict(dynamic.Dynamic, dynamic.Dynamic)

/// Identity for Dynamic: wraps any term that has no stdlib constructor.
@external(erlang, "mcl_bookclub_gleam_ffi", "wrap")
pub fn wrap(term: a) -> dynamic.Dynamic

/// An Erlang atom as a dynamic value (for payload keys and values).
pub fn atom(name: String) -> dynamic.Dynamic {
  atom.to_dynamic(atom.create(name))
}

/// A binary/string key as a dynamic value.
pub fn key(name: String) -> dynamic.Dynamic {
  dynamic.string(name)
}

/// An empty payload.
pub fn new() -> Payload {
  dict.new()
}
