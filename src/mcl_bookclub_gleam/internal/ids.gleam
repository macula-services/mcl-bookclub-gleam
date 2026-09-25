//// The reckon-db stream-id contract and the system clock -- the desk
//// essentials that are NOT the mesh SDK. The divisions may import this;
//// internal/mesh (macula, mcl_om, the wire reader) they may not, and the
//// boundary test pins that.

import gleam/dynamic
import mcl_bookclub_gleam/internal/payload.{atom}

/// reckon_gater_stream_id:new/1 -- mints an id with a prefix. The
/// AggregateId IS the reckon stream id (`^[a-z]{1,32}-[a-f0-9]{32}$'),
/// so the human name goes in the payload and this derived id is what the
/// command is addressed to. Never hand-roll the suffix.
@external(erlang, "reckon_gater_stream_id", "new")
pub fn mint_stream_id(prefix: String) -> String

/// reckon_gater_stream_id:validate/1, reshaped by the FFI (the Erlang side
/// returns a bare `ok' atom): {ok, nil} | {error, Reason}. The check every
/// desk runs BEFORE dispatch, because a bad stream id RAISES in the store
/// client (Demon 67).
@external(erlang, "mcl_bookclub_gleam_ffi", "validate_stream_id")
pub fn validate_stream_id(id: String) -> Result(Nil, dynamic.Dynamic)

/// The system clock, for event timestamps (milliseconds, like the twins).
@external(erlang, "erlang", "system_time")
pub fn now_ms(unit: dynamic.Dynamic) -> Int

pub fn millisecond() -> dynamic.Dynamic {
  atom("millisecond")
}
