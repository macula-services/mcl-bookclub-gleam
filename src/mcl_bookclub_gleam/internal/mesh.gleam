//// The mesh edge: mcl_om boot, the wire reader, macula publish, fact
//// topics, and the reckon-db stream-id contract.
////
//// The ONLY modules in this package that may name the mesh SDK are the
//// facade's own modules (facts, handler, emitters); everything here is a
//// thin binding, and the division boundary test keeps the SDK out of
//// host/project/query.

import gleam/dynamic
import mcl_bookclub_gleam/internal/payload.{atom, type Payload}

/// mcl_om:boot/1 -- the one-call lifecycle wiring: mesh pool, realm
/// identity, health registration, and (because the service exports
/// store_id/0 + data_dir/0) the reckon-db store and its evoq subscription
/// BEFORE ServiceMod:start/1 fires.
@external(erlang, "mcl_om", "boot")
pub fn boot(service_module: dynamic.Dynamic) -> Result(dynamic.Dynamic, dynamic.Dynamic)

/// The mesh handles the emitters publish through: {ok, {Pool, Realm}} |
/// {error, Reason}. Reshaped from mcl_om's three-tuple by
/// mcl_bookclub_gleam_ffi.
@external(erlang, "mcl_bookclub_gleam_ffi", "mesh_handles")
pub fn mesh_handles() -> Result(#(dynamic.Dynamic, dynamic.Dynamic), dynamic.Dynamic)

/// macula:publish/4 -- the fact leaves on the pool's link. ok | {error, _}.
@external(erlang, "macula", "publish")
pub fn publish(
  pool: dynamic.Dynamic,
  realm: dynamic.Dynamic,
  topic: String,
  fact: Payload,
) -> Result(Nil, dynamic.Dynamic)

/// macula_topic:app_fact/6 -- the fact topic name: one topic per fact
/// kind, ids and names in the payload, never the topic.
@external(erlang, "macula_topic", "app_fact")
pub fn app_fact_topic(
  realm_name: String,
  org: String,
  app: String,
  domain: String,
  name: String,
  version: Int,
) -> String

/// mcl_om_wire:field/2 -- the tolerant payload reader (Demon 65): accepts
/// atom or binary keys, resolves the CBOR {text, Bin} shape, and unwraps
/// the value in one call. Read anything wire-shaped with this.
@external(erlang, "mcl_om_wire", "field")
pub fn field(key: dynamic.Dynamic, payload: Payload) -> dynamic.Dynamic

@external(erlang, "mcl_om_wire", "unwrap")
pub fn unwrap(value: dynamic.Dynamic) -> dynamic.Dynamic

/// reckon_gater_stream_id: the reckon-db stream id contract. new/1 mints an
/// id with a prefix; validate/1 is the check every desk runs BEFORE
/// dispatch, because a bad stream id RAISES in the store client (Demon 67).
@external(erlang, "reckon_gater_stream_id", "new")
pub fn mint_stream_id(prefix: String) -> String

@external(erlang, "reckon_gater_stream_id", "validate")
pub fn validate_stream_id(id: String) -> Result(Nil, dynamic.Dynamic)

/// The system clock, for event timestamps (milliseconds, like the twins).
@external(erlang, "erlang", "system_time")
pub fn now_ms(unit: dynamic.Dynamic) -> Int

pub fn millisecond() -> dynamic.Dynamic {
  atom("millisecond")
}
