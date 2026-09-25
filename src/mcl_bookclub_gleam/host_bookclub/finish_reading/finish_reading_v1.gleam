//// The finish_reading_v1 command: a member finishes reading a book.
////
//// The command names the reading's stream id and the pages read. Everything
//// else the finished event needs comes from the aggregate state, echoed into
//// the event. The payload keys are ATOMS -- evoq reads command_type with an
//// atom lookup.

import gleam/dict
import gleam/dynamic
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/payload.{type Payload, atom}

pub type FinishReading {
  FinishReading(reading_id: String, pages_read: Int)
}

/// The command's type atom -- the same atom to_map/1 stamps into the
/// payload, which the aggregate's execute/2 dispatches on.
pub fn command_type() -> dynamic.Dynamic {
  atom("finish_reading_v1")
}

/// The command's payload: the reading's id (required, non-empty) and the
/// pages read (required, non-negative). The error atoms match the twins:
/// a missing field is missing_required_fields, a bad value is
/// invalid_params.
pub fn new(params: Payload) -> Result(FinishReading, dynamic.Dynamic) {
  case desk.get_string(params, "reading_id") {
    Ok(reading_id) ->
      case desk.get_int(params, "pages_read") {
        Ok(pages_read) ->
          case reading_id != "" && pages_read >= 0 {
            True ->
              Ok(FinishReading(reading_id: reading_id, pages_read: pages_read))
            False -> Error(desk.invalid_params())
          }
        Error(e) -> Error(e)
      }
    Error(e) -> Error(e)
  }
}

/// Checks about the world, not the shape: the reading id must satisfy
/// the reckon-db stream contract.
pub fn validate(command: FinishReading) -> Result(Nil, dynamic.Dynamic) {
  desk.validate_stream_ids([command.reading_id])
}

/// The payload the aggregate's execute/2 sees: atom keys, command_type
/// included.
pub fn to_map(command: FinishReading) -> Payload {
  dict.from_list([
    #(command_type_key(), command_type()),
    #(atom("reading_id"), dynamic.string(command.reading_id)),
    #(atom("pages_read"), dynamic.int(command.pages_read)),
  ])
}

pub fn from_map(params: Payload) -> Result(FinishReading, dynamic.Dynamic) {
  new(params)
}

/// The stream the command is addressed to: the reading's own id.
pub fn stream_id(command: FinishReading) -> String {
  command.reading_id
}

pub fn get_reading_id(command: FinishReading) -> String {
  command.reading_id
}

pub fn get_pages_read(command: FinishReading) -> Int {
  command.pages_read
}

fn command_type_key() -> dynamic.Dynamic {
  atom("command_type")
}
