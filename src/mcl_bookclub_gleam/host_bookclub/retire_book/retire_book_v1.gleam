//// The retire_book_v1 command: soft-delete the book.
////
//// `retire', the shelf-domain verb for a book leaving the shelf -- never
//// delete. Everything else the retired event needs comes from the
//// aggregate state, echoed into the event. The payload keys are ATOMS --
//// evoq reads command_type with an atom lookup.

import gleam/dict
import gleam/dynamic
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/payload.{type Payload, atom}

pub type RetireBook {
  RetireBook(book_id: String, retired_by: String)
}

/// The command's type atom -- the same atom to_map/1 stamps into the
/// payload, which the aggregate's execute/2 dispatches on.
pub fn command_type() -> dynamic.Dynamic {
  atom("retire_book_v1")
}

/// The command's payload: both fields are required binaries.
pub fn new(params: Payload) -> Result(RetireBook, dynamic.Dynamic) {
  case
    desk.get_string(params, "book_id"),
    desk.get_string(params, "retired_by")
  {
    Ok(book_id), Ok(retired_by) ->
      case book_id != "" && retired_by != "" {
        True -> Ok(RetireBook(book_id: book_id, retired_by: retired_by))
        False -> Error(desk.invalid_params())
      }
    _, _ -> Error(desk.missing_required_fields())
  }
}

/// Checks about the world, not the shape: the book id must satisfy the
/// reckon-db stream contract.
pub fn validate(command: RetireBook) -> Result(Nil, dynamic.Dynamic) {
  desk.validate_stream_ids([command.book_id])
}

/// The payload the aggregate's execute/2 sees: atom keys, command_type
/// included.
pub fn to_map(command: RetireBook) -> Payload {
  dict.from_list([
    #(command_type_key(), command_type()),
    #(atom("book_id"), dynamic.string(command.book_id)),
    #(atom("retired_by"), dynamic.string(command.retired_by)),
  ])
}

pub fn from_map(params: Payload) -> Result(RetireBook, dynamic.Dynamic) {
  new(params)
}

/// The stream the command is addressed to: the book's own id.
pub fn stream_id(command: RetireBook) -> String {
  command.book_id
}

pub fn get_book_id(command: RetireBook) -> String {
  command.book_id
}

pub fn get_retired_by(command: RetireBook) -> String {
  command.retired_by
}

fn command_type_key() -> dynamic.Dynamic {
  atom("command_type")
}
