//// The admin UI's wire edges: jsx for JSON, cowboy for the HTTP listener.
////
//// These live behind the facade's admin module; the division apps never
//// import them. jsx decode goes through the FFI's tolerant
//// decode_atoms/1 -- a body the decoder cannot read is empty params, not
//// a crash.

import gleam/dynamic
import gleam/erlang/process
import mcl_bookclub_gleam/internal/payload.{atom}

/// jsx:encode/1 -- any term to a JSON binary.
@external(erlang, "jsx", "encode")
pub fn encode(term: dynamic.Dynamic) -> String

/// jsx decode with atom labels, tolerant of anything undecodable (the FFI
/// returns an empty map instead of raising).
@external(erlang, "mcl_bookclub_gleam_ffi", "decode_atoms")
pub fn decode_atoms(body: String) -> dynamic.Dynamic

/// cowboy:start_clear/3 -- the plain-HTTP listener (the twins' admin
/// listeners are clear, LAN-facing). Returns the listener pid.
@external(erlang, "cowboy", "start_clear")
pub fn start_clear(
  ref: dynamic.Dynamic,
  transport_opts: List(dynamic.Dynamic),
  protocol_opts: dynamic.Dynamic,
) -> Result(process.Pid, dynamic.Dynamic)

/// cowboy_router:compile/1 -- the dispatch table.
@external(erlang, "cowboy_router", "compile")
pub fn compile_routes(routes: List(dynamic.Dynamic)) -> dynamic.Dynamic

/// ranch:get_port/1 -- read the ephemeral port back (integration tests use
/// port 0).
@external(erlang, "ranch", "get_port")
pub fn get_port(ref: dynamic.Dynamic) -> dynamic.Dynamic

/// cowboy_req accessors used by the single-shot handler.
@external(erlang, "cowboy_req", "method")
pub fn method(req: dynamic.Dynamic) -> String

@external(erlang, "cowboy_req", "path_info")
pub fn path_info(req: dynamic.Dynamic) -> List(String)

/// cowboy_req:read_body/1 reshaped by the FFI: {ok, {Body, Req}}.
@external(erlang, "mcl_bookclub_gleam_ffi", "read_body")
pub fn read_body(req: dynamic.Dynamic) -> Result(#(String, dynamic.Dynamic), dynamic.Dynamic)

@external(erlang, "cowboy_req", "reply")
pub fn reply(
  status: Int,
  headers: dynamic.Dynamic,
  body: String,
  req: dynamic.Dynamic,
) -> dynamic.Dynamic

/// The atom for the `_` catch-all host in cowboy routes.
pub fn any_host() -> dynamic.Dynamic {
  atom("_")
}

/// The content-type header map for JSON replies.
pub fn json_headers() -> dynamic.Dynamic {
  dynamic.properties([
    #(dynamic.string("content-type"), dynamic.string("application/json")),
  ])
}
