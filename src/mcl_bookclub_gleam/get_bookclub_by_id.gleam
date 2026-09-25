//// The mesh face of get_bookclub_by_id, advertised as
//// `mcl-bookclub/get_bookclub_by_id'.
////
//// The capability handler -- the one place the QRY desk's answer crosses
//// onto the mesh. The desk stays pure (no mesh, no wire); this module
//// adapts between the wire and it: parameters arrive atom-keyed or
//// binary-keyed or CBOR-text-wrapped (all three exist in the wild), so
//// they are read with mcl_om_wire:field/2 -- the tolerant reader the
//// corpus's Demon 65 prescribes -- and the reply's text goes back out as
//// CBOR text.

import gleam/dict
import gleam/dynamic
import mcl_bookclub_gleam/facts
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/mesh
import mcl_bookclub_gleam/internal/payload.{type Payload, atom, wrap}
import mcl_bookclub_gleam/query_bookclub/get_bookclub_by_id/get_bookclub_by_id

/// macula_response behaviour: init/1 answers {ok, State}.
pub fn init(
  _args: dynamic.Dynamic,
) -> Result(dynamic.Dynamic, dynamic.Dynamic) {
  Ok(atom("undefined"))
}

/// macula_response behaviour: handle_request/2 answers
/// {reply, Fact, State} or {error, Reason, State}.
pub fn handle_request(
  payload: Payload,
  state: dynamic.Dynamic,
) -> dynamic.Dynamic {
  let club_id = mesh.unwrap(mesh.field(atom("club_id"), payload))
  replied(club_id, state)
}

fn replied(
  club_id: dynamic.Dynamic,
  state: dynamic.Dynamic,
) -> dynamic.Dynamic {
  case desk.string_from_dynamic(club_id) {
    Ok(id) -> replied_found(id, state)
    Error(_) -> error_reply(atom("missing_club_id"), state)
  }
}

fn replied_found(id: String, state: dynamic.Dynamic) -> dynamic.Dynamic {
  case get_bookclub_by_id.find(id) {
    Ok(club) -> wrap(#(atom("reply"), to_wire(club), state))
    Error(reason) -> error_reply(reason, state)
  }
}

fn error_reply(
  reason: dynamic.Dynamic,
  state: dynamic.Dynamic,
) -> dynamic.Dynamic {
  wrap(#(atom("error"), reason, state))
}

/// The reply's values go back out as CBOR text / 1 / 0.
fn to_wire(club: Payload) -> dynamic.Dynamic {
  desk.payload_to_dynamic(
    dict.map_values(club, fn(_key, value) { facts.to_wire(value) }),
  )
}
