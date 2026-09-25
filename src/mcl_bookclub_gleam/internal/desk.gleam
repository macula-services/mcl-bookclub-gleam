//// The desk's shared shape: the dispatch result, the error atoms, the
//// tolerant payload readers, and the evoq dispatch call every desk makes.
////
//// A CMD desk = command module + maybe_ module (the business rule) + event
//// module + api module (the HTTP entry point). The maybe_ module's
//// dispatch/1 is the boundary where stream ids are validated BEFORE the
//// store client sees them (Demon 67: a bad id RAISES in the store client).

import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import mcl_bookclub_gleam/internal/evoq
import mcl_bookclub_gleam/internal/ids
import mcl_bookclub_gleam/internal/payload.{atom, type Payload}

/// What the aggregate's execute/2 and the maybe_ modules return: the
/// accepted event maps, or a refusal.
pub type DeskResult =
  Result(List(Payload), dynamic.Dynamic)

/// What a dispatch returns to the caller: the applied version and the
/// event maps, or a refusal. The dispatch result IS the only error
/// channel -- it is returned, never discarded.
pub type DispatchResult =
  Result(#(Int, List(Payload)), dynamic.Dynamic)

/// The one metadata key every dispatch carries: the command timestamp.
pub fn command_metadata() -> Payload {
  dict.from_list([#(atom("timestamp"), dynamic.int(ids.now_ms(ids.millisecond())))])
}

/// The dispatch every desk performs: build the evoq command, dispatch it
/// against the club's store. The module atoms name our own Gleam modules
/// (their Erlang names are the slash-paths with `@' separators).
pub fn dispatch_command(
  command_module: String,
  aggregate_module: String,
  stream_id: String,
  payload: Payload,
) -> DispatchResult {
  let command =
    evoq.command(
      atom(command_module),
      atom(aggregate_module),
      stream_id,
      payload,
      command_metadata(),
    )
  evoq.dispatch(command, evoq.dispatch_opts())
}

/// Read a payload field tolerantly: the atom key first (the in-memory
/// command shape), then the binary key (an event read back from the store
/// or a wire-shaped payload). Missing means `missing_required_fields`.
pub fn get(payload: Payload, key_name: String) -> Result(dynamic.Dynamic, dynamic.Dynamic) {
  case dict.get(payload, atom(key_name)) {
    Ok(value) -> Ok(value)
    Error(_) ->
      case dict.get(payload, dynamic.string(key_name)) {
        Ok(value) -> Ok(value)
        Error(_) -> Error(missing_required_fields())
      }
  }
}

/// Read a required string field.
pub fn get_string(payload: Payload, key_name: String) -> Result(String, dynamic.Dynamic) {
  case get(payload, key_name) {
    Ok(value) -> string_from_dynamic(value)
    Error(e) -> Error(e)
  }
}

/// Coerce a dynamic value to a String (the aggregate ids evoq hands back).
pub fn string_from_dynamic(value: dynamic.Dynamic) -> Result(String, dynamic.Dynamic) {
  case decode.run(value, decode.string) {
    Ok(string) -> Ok(string)
    Error(_) -> Error(invalid_params())
  }
}

/// Read an optional string field with a default (the twins' club_name
/// pattern: absent means the empty binary).
pub fn get_string_default(payload: Payload, key_name: String, default: String) -> String {
  case get_string(payload, key_name) {
    Ok(value) -> value
    Error(_) -> default
  }
}

/// Read an optional int field with a default.
pub fn get_int_default(payload: Payload, key_name: String, default: Int) -> Int {
  case get(payload, key_name) {
    Ok(value) ->
      case decode.run(value, decode.int) {
        Ok(int) -> int
        Error(_) -> default
      }
    Error(_) -> default
  }
}

/// Read a required int field (finish_reading_v1's pages_read).
pub fn get_int(payload: Payload, key_name: String) -> Result(Int, dynamic.Dynamic) {
  case get(payload, key_name) {
    Ok(value) ->
      case decode.run(value, decode.int) {
        Ok(int) -> Ok(int)
        Error(_) -> Error(invalid_params())
      }
    Error(e) -> Error(e)
  }
}

/// Is this payload a command of the given type? The aggregate dispatches
/// on the command_type atom the command's to_map/1 stamped in.
pub fn command_is(payload: Payload, command_type: String) -> Bool {
  case get(payload, "command_type") {
    Ok(atom_value) -> atom_value == atom(command_type)
    Error(_) -> False
  }
}

/// The event's type name, read tolerantly (atom or binary key).
pub fn event_type_of(payload: Payload) -> String {
  case get(payload, "event_type") {
    Ok(value) ->
      case decode.run(value, decode.string) {
        Ok(string) -> string
        Error(_) -> ""
      }
    Error(_) -> ""
  }
}

/// The event's business fields: inline for a raw event, under `data' for a
/// stored envelope. Read tolerantly -- matching one shape only is a bug
/// that shows up on the second command, never the first.
pub fn event_data(payload: Payload) -> Payload {
  case dict.get(payload, atom("data")) {
    Ok(inner) ->
      case decode_map(inner) {
        Ok(map) -> map
        Error(_) -> payload
      }
    Error(_) -> payload
  }
}

/// Decode a dynamic map into a Payload (the snapshot path).
pub fn decode_map(value: dynamic.Dynamic) -> Result(Payload, dynamic.Dynamic) {
  case decode.run(value, decode.dict(decode.dynamic, decode.dynamic)) {
    Ok(map) -> Ok(map)
    Error(e) -> Error(payload.wrap(e))
  }
}

/// Turn a Payload back into a dynamic map (the snapshot path).
pub fn payload_to_dynamic(payload: Payload) -> dynamic.Dynamic {
  dynamic.properties(dict.to_list(payload))
}

/// The shared error atoms. Each is a bare atom term on the wire and in
/// evoq's retry machinery.
pub fn missing_required_fields() -> dynamic.Dynamic {
  atom("missing_required_fields")
}

pub fn invalid_params() -> dynamic.Dynamic {
  atom("invalid_params")
}

pub fn unknown_command() -> dynamic.Dynamic {
  atom("unknown_command")
}

/// An arbitrary refusal atom, e.g. already_registered, not_initiated.
pub fn error_atom(name: String) -> dynamic.Dynamic {
  atom(name)
}

/// Validate a list of stream ids: the FIRST error wins, `Ok(Nil)`
/// otherwise. Run this BEFORE dispatch in every desk.
pub fn validate_stream_ids(ids: List(String)) -> Result(Nil, dynamic.Dynamic) {
  case ids {
    [] -> Ok(Nil)
    [id, ..rest] ->
      case ids.validate_stream_id(id) {
        Ok(_) -> validate_stream_ids(rest)
        Error(reason) -> Error(reason)
      }
  }
}
