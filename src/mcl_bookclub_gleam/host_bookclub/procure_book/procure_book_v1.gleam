//// The procure_book_v1 command: the club acquires a book for its shelf.
////
//// `procure', the business verb for acquisition -- never add. The command
//// names the book's stream id (minted, never derived from the title), the
//// club, and the bibliographic facts. The payload keys are ATOMS -- evoq
//// reads command_type with an atom lookup.

import gleam/dict
import gleam/dynamic
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/mesh
import mcl_bookclub_gleam/internal/payload.{atom, type Payload}

pub type ProcureBook {
  ProcureBook(
    book_id: String,
    club_id: String,
    title: String,
    author: String,
    club_name: String,
  )
}

/// The command's type atom -- the same atom to_map/1 stamps into the
/// payload, which the aggregate's execute/2 dispatches on.
pub fn command_type() -> dynamic.Dynamic {
  atom("procure_book_v1")
}

/// Mint the book's stream id. The AggregateId IS the reckon stream id
/// (`^[a-z]{1,32}-[a-f0-9]{32}$'), so the title goes in the payload and
/// this derived id is what the command is addressed to. Never hand-roll
/// the suffix; reckon_gater_stream_id:new/1 mints the contract.
pub fn mint_book_id() -> String {
  mesh.mint_stream_id("book")
}

/// The command's payload: required fields are binaries, club_name
/// defaults to the empty binary (the entry point stamps it in later).
pub fn new(params: Payload) -> Result(ProcureBook, dynamic.Dynamic) {
  case desk.get_string(params, "book_id"),
    desk.get_string(params, "club_id"),
    desk.get_string(params, "title"),
    desk.get_string(params, "author")
  {
    Ok(book_id), Ok(club_id), Ok(title), Ok(author) ->
      case book_id != "" && club_id != "" && title != "" && author != "" {
        True ->
          Ok(ProcureBook(
            book_id: book_id,
            club_id: club_id,
            title: title,
            author: author,
            club_name: desk.get_string_default(params, "club_name", ""),
          ))
        False -> Error(desk.invalid_params())
      }
    _, _, _, _ -> Error(desk.missing_required_fields())
  }
}

/// Checks about the world, not the shape: both stream ids must satisfy
/// the reckon-db stream contract.
pub fn validate(command: ProcureBook) -> Result(Nil, dynamic.Dynamic) {
  desk.validate_stream_ids([command.book_id, command.club_id])
}

/// The payload the aggregate's execute/2 sees: atom keys, command_type
/// included.
pub fn to_map(command: ProcureBook) -> Payload {
  dict.from_list([
    #(command_type_key(), command_type()),
    #(atom("book_id"), dynamic.string(command.book_id)),
    #(atom("club_id"), dynamic.string(command.club_id)),
    #(atom("title"), dynamic.string(command.title)),
    #(atom("author"), dynamic.string(command.author)),
    #(atom("club_name"), dynamic.string(command.club_name)),
  ])
}

pub fn from_map(params: Payload) -> Result(ProcureBook, dynamic.Dynamic) {
  new(params)
}

/// The stream the command is addressed to: the book's own id.
pub fn stream_id(command: ProcureBook) -> String {
  command.book_id
}

pub fn get_book_id(command: ProcureBook) -> String {
  command.book_id
}

pub fn get_club_id(command: ProcureBook) -> String {
  command.club_id
}

pub fn get_title(command: ProcureBook) -> String {
  command.title
}

pub fn get_author(command: ProcureBook) -> String {
  command.author
}

pub fn get_club_name(command: ProcureBook) -> String {
  command.club_name
}

fn command_type_key() -> dynamic.Dynamic {
  atom("command_type")
}
