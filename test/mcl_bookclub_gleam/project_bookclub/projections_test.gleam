//// The 8 PRJ projections, driven directly: each handle_event/4 writes one
//// idempotent row through the shared read-model store actor, and the row
//// is read back with the exact SELECT the schema declares.
////
//// The store actor registers under a fixed name, so every test in the VM
//// shares ONE connection: ensure_store_actor/0's start wins once, every
//// later start is refused and ignored, and rows are keyed by freshly
//// minted stream ids -- cross-test state on the shared connection is
//// harmless.
////
//// Every expected status string is derived from the CMD status module's
//// flag map (bookclub_status.to_string/1 and friends), never spelled here
//// as a literal -- Demon 68.

import gleam/dict
import gleam/dynamic
import gleam/int
import gleam/list
import gleam/string
import gleeunit/should
import mcl_bookclub_gleam/host_bookclub/book_status
import mcl_bookclub_gleam/host_bookclub/bookclub_status
import mcl_bookclub_gleam/host_bookclub/member_status
import mcl_bookclub_gleam/host_bookclub/reading_status
import mcl_bookclub_gleam/internal/evoq
import mcl_bookclub_gleam/internal/ids
import mcl_bookclub_gleam/internal/payload.{type Payload, atom, wrap}
import mcl_bookclub_gleam/project_bookclub/book_procured/book_procured_v1_to_sqlite_books
import mcl_bookclub_gleam/project_bookclub/book_retired/book_retired_v1_to_sqlite_books
import mcl_bookclub_gleam/project_bookclub/bookclub_archived/bookclub_archived_v1_to_sqlite_clubs
import mcl_bookclub_gleam/project_bookclub/bookclub_initiated/bookclub_initiated_v1_to_sqlite_clubs
import mcl_bookclub_gleam/project_bookclub/bookclub_read_model_store
import mcl_bookclub_gleam/project_bookclub/member_registered/member_registered_v1_to_sqlite_members
import mcl_bookclub_gleam/project_bookclub/member_unregistered/member_unregistered_v1_to_sqlite_members
import mcl_bookclub_gleam/project_bookclub/reading_finished/reading_finished_v1_to_sqlite_readings
import mcl_bookclub_gleam/project_bookclub/reading_started/reading_started_v1_to_sqlite_readings
import mcl_bookclub_gleam/test_support

/// Start the store actor on a unique path and ignore the error: the first
/// caller in the VM wins the fixed name and creates the schema; later
/// tests reuse whatever connection exists.
fn ensure_store_actor() -> Nil {
  let _ =
    bookclub_read_model_store.start(
      "/tmp/mcl_bookclub_gleam_prj_tests/"
      <> int.to_string(test_support.unique_integer([wrap(atom("positive"))]))
      <> "/bookclub.sqlite3",
    )
  Nil
}

/// An inline-shaped event envelope: the business fields at the top level,
/// plus the applied position (event_id, version) the row will carry.
fn envelope(
  event_type: String,
  event_id: String,
  version: Int,
  fields: List(#(dynamic.Dynamic, dynamic.Dynamic)),
) -> Payload {
  dict.from_list([
    #(atom("event_type"), dynamic.string(event_type)),
    #(atom("event_id"), dynamic.string(event_id)),
    #(atom("version"), dynamic.int(version)),
    ..fields
  ])
}

pub fn a_bookclub_initiated_event_projects_a_clubs_row_test() {
  ensure_store_actor()
  let club_id = ids.mint_stream_id("bookclub")
  let event =
    envelope("bookclub_initiated_v1", "evt-init-1", 0, [
      #(atom("club_id"), dynamic.string(club_id)),
      #(atom("name"), dynamic.string("The Crooked Shelf")),
      #(atom("initiated_by"), dynamic.string("bea")),
      #(atom("initiated_at"), dynamic.int(42)),
    ])
  let assert Ok(_) =
    bookclub_initiated_v1_to_sqlite_clubs.handle_event(
      "",
      event,
      dict.new(),
      evoq.empty_state(),
    )
  let assert Ok([
    [row_club_id, row_name, row_status, row_by, row_at, row_event, row_version],
  ]) =
    bookclub_read_model_store.q(
      "SELECT club_id, name, status, initiated_by, initiated_at, event_id, version"
        <> " FROM clubs WHERE club_id = ?",
      [dynamic.string(club_id)],
    )
  row_club_id |> should.equal(dynamic.string(club_id))
  row_name |> should.equal(dynamic.string("The Crooked Shelf"))
  row_status
  |> should.equal(
    dynamic.string(bookclub_status.to_string(bookclub_status.initiated())),
  )
  row_by |> should.equal(dynamic.string("bea"))
  row_at |> should.equal(dynamic.int(42))
  row_event |> should.equal(dynamic.string("evt-init-1"))
  row_version |> should.equal(dynamic.int(0))
}

pub fn a_bookclub_archived_event_projects_a_clubs_row_test() {
  ensure_store_actor()
  let club_id = ids.mint_stream_id("bookclub")
  let event =
    envelope("bookclub_archived_v1", "evt-arch-1", 1, [
      #(atom("club_id"), dynamic.string(club_id)),
      #(atom("name"), dynamic.string("The Closed Chapter")),
      #(atom("initiated_by"), dynamic.string("bea")),
      #(atom("initiated_at"), dynamic.int(42)),
    ])
  let assert Ok(_) =
    bookclub_archived_v1_to_sqlite_clubs.handle_event(
      "",
      event,
      dict.new(),
      evoq.empty_state(),
    )
  let assert Ok([
    [row_club_id, row_name, row_status, row_by, row_at, row_event, row_version],
  ]) =
    bookclub_read_model_store.q(
      "SELECT club_id, name, status, initiated_by, initiated_at, event_id, version"
        <> " FROM clubs WHERE club_id = ?",
      [dynamic.string(club_id)],
    )
  row_club_id |> should.equal(dynamic.string(club_id))
  row_name |> should.equal(dynamic.string("The Closed Chapter"))
  row_status
  |> should.equal(
    dynamic.string(bookclub_status.to_string(bookclub_status.archived())),
  )
  row_by |> should.equal(dynamic.string("bea"))
  row_at |> should.equal(dynamic.int(42))
  row_event |> should.equal(dynamic.string("evt-arch-1"))
  row_version |> should.equal(dynamic.int(1))
}

pub fn a_member_registered_event_projects_a_members_row_test() {
  ensure_store_actor()
  let member_id = ids.mint_stream_id("member")
  let club_id = ids.mint_stream_id("bookclub")
  let event =
    envelope("member_registered_v1", "evt-mem-1", 0, [
      #(atom("member_id"), dynamic.string(member_id)),
      #(atom("club_id"), dynamic.string(club_id)),
      #(atom("name"), dynamic.string("Bea")),
      #(atom("registered_at"), dynamic.int(100)),
    ])
  let assert Ok(_) =
    member_registered_v1_to_sqlite_members.handle_event(
      "",
      event,
      dict.new(),
      evoq.empty_state(),
    )
  let assert Ok([
    [
      row_member_id,
      row_club_id,
      row_name,
      row_status,
      row_at,
      row_event,
      row_version,
    ],
  ]) =
    bookclub_read_model_store.q(
      "SELECT member_id, club_id, name, status, registered_at, event_id, version"
        <> " FROM members WHERE member_id = ?",
      [dynamic.string(member_id)],
    )
  row_member_id |> should.equal(dynamic.string(member_id))
  row_club_id |> should.equal(dynamic.string(club_id))
  row_name |> should.equal(dynamic.string("Bea"))
  row_status
  |> should.equal(
    dynamic.string(member_status.to_string(member_status.registered())),
  )
  row_at |> should.equal(dynamic.int(100))
  row_event |> should.equal(dynamic.string("evt-mem-1"))
  row_version |> should.equal(dynamic.int(0))
}

pub fn a_member_unregistered_event_projects_a_members_row_test() {
  ensure_store_actor()
  let member_id = ids.mint_stream_id("member")
  let club_id = ids.mint_stream_id("bookclub")
  let event =
    envelope("member_unregistered_v1", "evt-mem-2", 1, [
      #(atom("member_id"), dynamic.string(member_id)),
      #(atom("club_id"), dynamic.string(club_id)),
      #(atom("name"), dynamic.string("Bea")),
      #(atom("registered_at"), dynamic.int(100)),
    ])
  let assert Ok(_) =
    member_unregistered_v1_to_sqlite_members.handle_event(
      "",
      event,
      dict.new(),
      evoq.empty_state(),
    )
  let assert Ok([
    [
      row_member_id,
      row_club_id,
      row_name,
      row_status,
      row_at,
      row_event,
      row_version,
    ],
  ]) =
    bookclub_read_model_store.q(
      "SELECT member_id, club_id, name, status, registered_at, event_id, version"
        <> " FROM members WHERE member_id = ?",
      [dynamic.string(member_id)],
    )
  row_member_id |> should.equal(dynamic.string(member_id))
  row_club_id |> should.equal(dynamic.string(club_id))
  row_name |> should.equal(dynamic.string("Bea"))
  row_status
  |> should.equal(
    dynamic.string(member_status.to_string(member_status.unregistered())),
  )
  row_at |> should.equal(dynamic.int(100))
  row_event |> should.equal(dynamic.string("evt-mem-2"))
  row_version |> should.equal(dynamic.int(1))
}

pub fn a_book_procured_event_projects_a_books_row_test() {
  ensure_store_actor()
  let book_id = ids.mint_stream_id("book")
  let club_id = ids.mint_stream_id("bookclub")
  let event =
    envelope("book_procured_v1", "evt-book-1", 0, [
      #(atom("book_id"), dynamic.string(book_id)),
      #(atom("club_id"), dynamic.string(club_id)),
      #(atom("title"), dynamic.string("The Hobbit")),
      #(atom("author"), dynamic.string("J.R.R. Tolkien")),
      #(atom("procured_at"), dynamic.int(300)),
    ])
  let assert Ok(_) =
    book_procured_v1_to_sqlite_books.handle_event(
      "",
      event,
      dict.new(),
      evoq.empty_state(),
    )
  let assert Ok([
    [
      row_book_id,
      row_club_id,
      row_title,
      row_author,
      row_status,
      row_at,
      row_event,
      row_version,
    ],
  ]) =
    bookclub_read_model_store.q(
      "SELECT book_id, club_id, title, author, status, procured_at, event_id, version"
        <> " FROM books WHERE book_id = ?",
      [dynamic.string(book_id)],
    )
  row_book_id |> should.equal(dynamic.string(book_id))
  row_club_id |> should.equal(dynamic.string(club_id))
  row_title |> should.equal(dynamic.string("The Hobbit"))
  row_author |> should.equal(dynamic.string("J.R.R. Tolkien"))
  row_status
  |> should.equal(dynamic.string(book_status.to_string(book_status.on_shelf())))
  row_at |> should.equal(dynamic.int(300))
  row_event |> should.equal(dynamic.string("evt-book-1"))
  row_version |> should.equal(dynamic.int(0))
}

pub fn a_book_retired_event_projects_a_books_row_test() {
  ensure_store_actor()
  let book_id = ids.mint_stream_id("book")
  let club_id = ids.mint_stream_id("bookclub")
  let event =
    envelope("book_retired_v1", "evt-book-2", 1, [
      #(atom("book_id"), dynamic.string(book_id)),
      #(atom("club_id"), dynamic.string(club_id)),
      #(atom("title"), dynamic.string("The Hobbit")),
      #(atom("author"), dynamic.string("J.R.R. Tolkien")),
      #(atom("procured_at"), dynamic.int(300)),
    ])
  let assert Ok(_) =
    book_retired_v1_to_sqlite_books.handle_event(
      "",
      event,
      dict.new(),
      evoq.empty_state(),
    )
  let assert Ok([
    [
      row_book_id,
      row_club_id,
      row_title,
      row_author,
      row_status,
      row_at,
      row_event,
      row_version,
    ],
  ]) =
    bookclub_read_model_store.q(
      "SELECT book_id, club_id, title, author, status, procured_at, event_id, version"
        <> " FROM books WHERE book_id = ?",
      [dynamic.string(book_id)],
    )
  row_book_id |> should.equal(dynamic.string(book_id))
  row_club_id |> should.equal(dynamic.string(club_id))
  row_title |> should.equal(dynamic.string("The Hobbit"))
  row_author |> should.equal(dynamic.string("J.R.R. Tolkien"))
  row_status
  |> should.equal(dynamic.string(book_status.to_string(book_status.retired())))
  row_at |> should.equal(dynamic.int(300))
  row_event |> should.equal(dynamic.string("evt-book-2"))
  row_version |> should.equal(dynamic.int(1))
}

pub fn a_reading_started_event_projects_a_readings_row_test() {
  ensure_store_actor()
  let reading_id = ids.mint_stream_id("reading")
  let member_id = ids.mint_stream_id("member")
  let book_id = ids.mint_stream_id("book")
  let event =
    envelope("reading_started_v1", "evt-read-1", 0, [
      #(atom("reading_id"), dynamic.string(reading_id)),
      #(atom("member_id"), dynamic.string(member_id)),
      #(atom("book_id"), dynamic.string(book_id)),
      #(atom("started_at"), dynamic.int(500)),
    ])
  let assert Ok(_) =
    reading_started_v1_to_sqlite_readings.handle_event(
      "",
      event,
      dict.new(),
      evoq.empty_state(),
    )
  let assert Ok([
    [
      row_reading_id,
      row_member_id,
      row_book_id,
      row_status,
      row_at,
      row_pages,
      row_finished,
      row_event,
      row_version,
    ],
  ]) =
    bookclub_read_model_store.q(
      "SELECT reading_id, member_id, book_id, status, started_at,"
        <> " pages_read, finished_at, event_id, version"
        <> " FROM readings WHERE reading_id = ?",
      [dynamic.string(reading_id)],
    )
  row_reading_id |> should.equal(dynamic.string(reading_id))
  row_member_id |> should.equal(dynamic.string(member_id))
  row_book_id |> should.equal(dynamic.string(book_id))
  row_status
  |> should.equal(
    dynamic.string(reading_status.to_string(reading_status.in_progress())),
  )
  row_at |> should.equal(dynamic.int(500))
  row_pages |> should.equal(dynamic.int(0))
  // A fresh reading has no finished_at: SQL NULL arrives as the atom
  // `undefined`.
  row_finished |> should.equal(atom("undefined"))
  row_event |> should.equal(dynamic.string("evt-read-1"))
  row_version |> should.equal(dynamic.int(0))
}

pub fn a_reading_finished_event_projects_a_readings_row_test() {
  ensure_store_actor()
  let reading_id = ids.mint_stream_id("reading")
  let member_id = ids.mint_stream_id("member")
  let book_id = ids.mint_stream_id("book")
  let event =
    envelope("reading_finished_v1", "evt-read-2", 1, [
      #(atom("reading_id"), dynamic.string(reading_id)),
      #(atom("member_id"), dynamic.string(member_id)),
      #(atom("book_id"), dynamic.string(book_id)),
      #(atom("started_at"), dynamic.int(500)),
      #(atom("pages_read"), dynamic.int(320)),
      #(atom("finished_at"), dynamic.int(999)),
    ])
  let assert Ok(_) =
    reading_finished_v1_to_sqlite_readings.handle_event(
      "",
      event,
      dict.new(),
      evoq.empty_state(),
    )
  let assert Ok([
    [
      row_reading_id,
      row_member_id,
      row_book_id,
      row_status,
      row_at,
      row_pages,
      row_finished,
      row_event,
      row_version,
    ],
  ]) =
    bookclub_read_model_store.q(
      "SELECT reading_id, member_id, book_id, status, started_at,"
        <> " pages_read, finished_at, event_id, version"
        <> " FROM readings WHERE reading_id = ?",
      [dynamic.string(reading_id)],
    )
  row_reading_id |> should.equal(dynamic.string(reading_id))
  row_member_id |> should.equal(dynamic.string(member_id))
  row_book_id |> should.equal(dynamic.string(book_id))
  row_status
  |> should.equal(
    dynamic.string(reading_status.to_string(reading_status.finished())),
  )
  row_at |> should.equal(dynamic.int(500))
  row_pages |> should.equal(dynamic.int(320))
  row_finished |> should.equal(dynamic.int(999))
  row_event |> should.equal(dynamic.string("evt-read-2"))
  row_version |> should.equal(dynamic.int(1))
}

/// The schema is the one copy of the read model's shape: exactly four
/// CREATE TABLE statements, one per table, each declaring its own name.
pub fn the_read_model_schema_has_the_four_tables_test() {
  let schema = bookclub_read_model_store.schema()
  schema |> list.length |> should.equal(4)
  let table_names =
    list.map(schema, fn(statement) {
      let assert Ok(#("", rest)) =
        string.split_once(statement, "CREATE TABLE IF NOT EXISTS ")
      let assert [table_name, ..] = string.split(rest, " ")
      table_name
    })
  table_names
  |> list.sort(string.compare)
  |> should.equal(["books", "clubs", "members", "readings"])
}
