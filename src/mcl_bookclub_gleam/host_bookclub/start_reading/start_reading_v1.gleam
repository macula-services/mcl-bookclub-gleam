//// The start_reading_v1 command: a member starts reading a book.
////
//// The reading is the child aggregate: the member's side identifies it (the
//// reading id is minted here), and the reading initiates itself with its own
//// birth event. The command carries the member and the book being read --
//// the parents the reading refers to. The payload keys are ATOMS -- evoq
//// reads command_type with an atom lookup.

import gleam/dict
import gleam/dynamic
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/ids
import mcl_bookclub_gleam/internal/payload.{atom, type Payload}

pub type StartReading {
  StartReading(
    reading_id: String,
    member_id: String,
    book_id: String,
  )
}

/// The command's type atom -- the same atom to_map/1 stamps into the
/// payload, which the aggregate's execute/2 dispatches on.
pub fn command_type() -> dynamic.Dynamic {
  atom("start_reading_v1")
}

/// Mint the reading's stream id. The AggregateId IS the reckon stream id
/// (`^[a-z]{1,32}-[a-f0-9]{32}$'), so the parents go in the payload
/// and this derived id is what the command is addressed to. Never
/// hand-roll the suffix; reckon_gater_stream_id:new/1 mints the contract.
pub fn mint_reading_id() -> String {
  ids.mint_stream_id("reading")
}

/// The command's payload: the reading, the member, and the book -- all
/// three required, none may be empty.
pub fn new(params: Payload) -> Result(StartReading, dynamic.Dynamic) {
  case desk.get_string(params, "reading_id"),
    desk.get_string(params, "member_id"),
    desk.get_string(params, "book_id")
  {
    Ok(reading_id), Ok(member_id), Ok(book_id) ->
      case reading_id != "" && member_id != "" && book_id != "" {
        True ->
          Ok(StartReading(
            reading_id: reading_id,
            member_id: member_id,
            book_id: book_id,
          ))
        False -> Error(desk.invalid_params())
      }
    _, _, _ -> Error(desk.missing_required_fields())
  }
}

/// Checks about the world, not the shape: every stream id must satisfy
/// the reckon-db stream contract.
pub fn validate(command: StartReading) -> Result(Nil, dynamic.Dynamic) {
  desk.validate_stream_ids([
    command.reading_id,
    command.member_id,
    command.book_id,
  ])
}

/// The payload the aggregate's execute/2 sees: atom keys, command_type
/// included.
pub fn to_map(command: StartReading) -> Payload {
  dict.from_list([
    #(command_type_key(), command_type()),
    #(atom("reading_id"), dynamic.string(command.reading_id)),
    #(atom("member_id"), dynamic.string(command.member_id)),
    #(atom("book_id"), dynamic.string(command.book_id)),
  ])
}

pub fn from_map(params: Payload) -> Result(StartReading, dynamic.Dynamic) {
  new(params)
}

/// The stream the command is addressed to: the reading's own id.
pub fn stream_id(command: StartReading) -> String {
  command.reading_id
}

pub fn get_reading_id(command: StartReading) -> String {
  command.reading_id
}

pub fn get_member_id(command: StartReading) -> String {
  command.member_id
}

pub fn get_book_id(command: StartReading) -> String {
  command.book_id
}

fn command_type_key() -> dynamic.Dynamic {
  atom("command_type")
}
