//// The health edge: the ping that cannot crash the caller.
////
//// gleam_otp actors are not gen_servers, so the twins' `try
//// gen_server:call(Name, ping, 1000) catch ... end` has no direct actor
//// equivalent that cannot crash. The FFI's safe_ping/2 (whereis, monitor,
//// ask, honest answer) is the actor-shaped equivalent, and send_reply/2 is
//// the store's half of the protocol. The message shape {ping, {Pid, Ref}}
//// is the runtime encoding of the stores' `Ping(reply_to: #(Pid, Ref))'
//// variant, so the actor's selector matches it.

import gleam/dynamic
import gleam/erlang/process
import mcl_bookclub_gleam/internal/payload

/// {ok, Reply} | {error, missing} | {error, {down, Reason}} | {error, timeout}.
/// `name` must be an atom (payload.atom/1 of the registered actor name).
@external(erlang, "mcl_bookclub_gleam_ffi", "safe_ping")
pub fn safe_ping(
  name: dynamic.Dynamic,
  timeout: Int,
) -> Result(dynamic.Dynamic, dynamic.Dynamic)

/// The store's half: reply {Ref, Reply} to the ping's {Pid, Ref}.
@external(erlang, "mcl_bookclub_gleam_ffi", "send_reply")
pub fn send_reply(reply_to: #(process.Pid, dynamic.Dynamic), reply: dynamic.Dynamic) -> Nil

/// The ok atom the stores answer with.
pub fn ok_reply() -> dynamic.Dynamic {
  payload.atom("ok")
}
