//// The evoq edge: commands, dispatch, bit flags, event handlers.
////
//// evoq is the CQRS/ES framework; its Erlang modules are called directly,
//// never wrapped (the corpus's "no wrapper" convention). Only shapes Gleam
//// cannot type (the dispatch three-tuple) go through
//// mcl_bookclub_gleam_ffi.

import gleam/dict
import gleam/dynamic
import gleam/erlang/process
import gleam/otp/actor
import gleam/string
import mcl_bookclub_gleam/internal/payload.{atom, new, type Payload}

/// Build an evoq command addressed at a stream. `command_type` and
/// `aggregate_type` are the Erlang module atoms of our own Gleam modules;
/// the payload carries `command_type` as an atom key because evoq reads it
/// with an atom lookup.
@external(erlang, "evoq_command", "new")
pub fn command(
  command_type: dynamic.Dynamic,
  aggregate_type: dynamic.Dynamic,
  aggregate_id: String,
  payload: Payload,
  metadata: Payload,
) -> dynamic.Dynamic

/// Dispatch a command through evoq to the reckon-db store. Returns
/// `Ok(#(version, events))` or `Error(reason)` -- the store client raises
/// on an invalid stream id, which is why every desk validates its stream
/// ids BEFORE calling this (Demon 67).
@external(erlang, "mcl_bookclub_gleam_ffi", "dispatch")
pub fn dispatch(
  command: dynamic.Dynamic,
  opts: Payload,
) -> Result(#(Int, List(Payload)), dynamic.Dynamic)

/// The dispatch opts every desk names: the club's store, the reckon-db
/// adapter, eventual consistency. The same three keys the twins use.
pub fn dispatch_opts() -> Payload {
  dict.from_list([
    #(atom("store_id"), atom("mcl_bookclub_store")),
    #(atom("adapter"), atom("reckon_evoq_adapter")),
    #(atom("consistency"), atom("eventual")),
  ])
}

/// The store id the whole service addresses -- the atom in one place. It
/// must agree with the `evoq` block in config/sys.config.src and with the
/// service's store_id/0; a test pins the three together.
pub fn store_id_atom() -> dynamic.Dynamic {
  atom("mcl_bookclub_store")
}

/// evoq_bit_flags: the bit-mask state the aggregates fold and the status
/// modules render readable (Demon 68: the flag map lives in the status
/// module; a projection spelling a status literal is refused by test).

@external(erlang, "evoq_bit_flags", "set")
pub fn bit_set(flags: Int, flag: Int) -> Int

@external(erlang, "evoq_bit_flags", "has")
pub fn bit_has(flags: Int, flag: Int) -> Bool

@external(erlang, "evoq_bit_flags", "to_string")
pub fn bit_to_string(flags: Int, flag_map: dict.Dict(Int, String)) -> String

/// Start an evoq event handler (a projection, policy or emitter desk) as a
/// supervised process. The module atom names one of our Gleam modules that
/// exports the handler callbacks (interested_in/0, init/1, handle_event/4,
/// replay_policy/0). Returns the raw gen_server pid -- `process.Pid` is an
/// opaque type whose runtime representation IS the erlang pid.
@external(erlang, "evoq_event_handler", "start_link")
pub fn start_handler(
  module: dynamic.Dynamic,
  config: Payload,
) -> Result(process.Pid, dynamic.Dynamic)

/// The replay policies a handler may declare. `Skip` for side-effect
/// handlers (emitters, the party policy): a restart's replay must not
/// repeat the side effect. `Deliver` for idempotent projections.
pub fn replay_skip() -> dynamic.Dynamic {
  atom("skip")
}

pub fn replay_deliver() -> dynamic.Dynamic {
  atom("deliver")
}

/// An empty handler config/state, as a dynamic map (init/1's return).
pub fn empty_state() -> dynamic.Dynamic {
  dynamic.properties(dict.to_list(new()))
}

/// The evoq event handler start, wrapped for the gleam_otp supervisor:
/// a child spec start function that reports StartError honestly.
pub fn handler_start(
  module: dynamic.Dynamic,
  config: Payload,
) -> Result(actor.Started(Nil), actor.StartError) {
  case start_handler(module, config) {
    Ok(pid) -> Ok(actor.Started(pid: pid, data: Nil))
    Error(reason) -> Error(actor.InitFailed(string.inspect(reason)))
  }
}
