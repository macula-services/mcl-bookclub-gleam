//// The 5 QRY desks, against both store actors.
////
//// The PRJ actor owns the schema and the seeding writes; the QRY actor
//// owns the reads (its API is q/2 only). The desks read through the QRY
//// actor's connection, so the two actors must open the SAME file: this
//// suite stops any store actor an earlier suite left registered (it owns
//// a different file), then starts a fresh PRJ+QRY pair on ONE shared
//// path -- PRJ first, because the PRJ actor creates the schema the QRY
//// actor assumes.
////
//// Seeding rides the real projections' handle_event/4; the desks then
//// answer from the rows those projections wrote.

import gleam/dict
import gleam/dynamic
import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/option
import gleeunit/should
import mcl_bookclub_gleam/host_bookclub/book_status
import mcl_bookclub_gleam/host_bookclub/bookclub_status
import mcl_bookclub_gleam/host_bookclub/member_status
import mcl_bookclub_gleam/host_bookclub/reading_status
import mcl_bookclub_gleam/internal/evoq
import mcl_bookclub_gleam/internal/ids
import mcl_bookclub_gleam/internal/payload.{type Payload, atom, wrap}
import mcl_bookclub_gleam/project_bookclub/book_procured/book_procured_v1_to_sqlite_books
import mcl_bookclub_gleam/project_bookclub/bookclub_initiated/bookclub_initiated_v1_to_sqlite_clubs
import mcl_bookclub_gleam/project_bookclub/bookclub_read_model_store
import mcl_bookclub_gleam/project_bookclub/member_registered/member_registered_v1_to_sqlite_members
import mcl_bookclub_gleam/project_bookclub/reading_started/reading_started_v1_to_sqlite_readings
import mcl_bookclub_gleam/query_bookclub/bookclub_query_store
import mcl_bookclub_gleam/query_bookclub/get_book_by_id/get_book_by_id
import mcl_bookclub_gleam/query_bookclub/get_bookclub_by_id/get_bookclub_by_id
import mcl_bookclub_gleam/query_bookclub/get_member_by_id/get_member_by_id
import mcl_bookclub_gleam/query_bookclub/get_reading_by_id/get_reading_by_id
import mcl_bookclub_gleam/query_bookclub/get_readings_by_member/get_readings_by_member
import mcl_bookclub_gleam/test_support

/// The Erlang whereis: the atom `undefined` when the name is free.
@external(erlang, "erlang", "whereis")
fn whereis(name: dynamic.Dynamic) -> dynamic.Dynamic

/// The Erlang unlink: cut the link so a kill cannot propagate back to the
/// process that started the actor (a test process).
@external(erlang, "erlang", "unlink")
fn unlink_process(pid: dynamic.Dynamic) -> dynamic.Dynamic

/// The Erlang exit/2: an untrappable kill signal.
@external(erlang, "erlang", "exit")
fn exit_process(
  pid: dynamic.Dynamic,
  reason: dynamic.Dynamic,
) -> dynamic.Dynamic

fn store_path() -> String {
  "/tmp/mcl_bookclub_gleam_prj_tests/"
  <> int.to_string(test_support.unique_integer([wrap(atom("positive"))]))
  <> "/bookclub.sqlite3"
}

/// Both actors on ONE path, for this one test: PRJ first (it creates the
/// schema), then QRY opening the same file. An actor an earlier suite left
/// registered owns a DIFFERENT file, so stop it first -- the fresh starts
/// here must win the names.
fn ensure_stores() -> Nil {
  stop_store_actor(atom("bookclub_read_model_store"))
  stop_store_actor(atom("bookclub_query_store"))
  let path = store_path()
  let assert Ok(_) = bookclub_read_model_store.start(path)
  let assert Ok(_) = bookclub_query_store.start(path)
  Nil
}

/// Stop the actor registered under the fixed name, if one is running, and
/// wait until the name is free again. The actor is linked to the test
/// process that started it, so the link is cut before the kill -- the kill
/// must not propagate back to this suite.
fn stop_store_actor(name: dynamic.Dynamic) -> Nil {
  case whereis(name) == atom("undefined") {
    True -> Nil
    False -> {
      let pid = whereis(name)
      let _ = unlink_process(pid)
      exit_process(pid, atom("kill"))
      await_released(name, 100)
    }
  }
}

fn await_released(name: dynamic.Dynamic, tries: Int) -> Nil {
  case whereis(name) == atom("undefined") {
    True -> Nil
    False ->
      case tries > 0 {
        True -> {
          process.sleep(10)
          await_released(name, tries - 1)
        }
        False -> Nil
      }
  }
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

fn seed_club(name: String, initiated_at: Int) -> String {
  let club_id = ids.mint_stream_id("bookclub")
  let event =
    envelope("bookclub_initiated_v1", "evt-q-1", 0, [
      #(atom("club_id"), dynamic.string(club_id)),
      #(atom("name"), dynamic.string(name)),
      #(atom("initiated_by"), dynamic.string("bea")),
      #(atom("initiated_at"), dynamic.int(initiated_at)),
    ])
  let assert Ok(_) =
    bookclub_initiated_v1_to_sqlite_clubs.handle_event(
      "",
      event,
      dict.new(),
      evoq.empty_state(),
    )
  club_id
}

fn seed_member(name: String, registered_at: Int) -> String {
  let member_id = ids.mint_stream_id("member")
  let event =
    envelope("member_registered_v1", "evt-q-2", 0, [
      #(atom("member_id"), dynamic.string(member_id)),
      #(atom("club_id"), dynamic.string(ids.mint_stream_id("bookclub"))),
      #(atom("name"), dynamic.string(name)),
      #(atom("registered_at"), dynamic.int(registered_at)),
    ])
  let assert Ok(_) =
    member_registered_v1_to_sqlite_members.handle_event(
      "",
      event,
      dict.new(),
      evoq.empty_state(),
    )
  member_id
}

fn seed_book(title: String, author: String, procured_at: Int) -> String {
  let book_id = ids.mint_stream_id("book")
  let event =
    envelope("book_procured_v1", "evt-q-3", 0, [
      #(atom("book_id"), dynamic.string(book_id)),
      #(atom("club_id"), dynamic.string(ids.mint_stream_id("bookclub"))),
      #(atom("title"), dynamic.string(title)),
      #(atom("author"), dynamic.string(author)),
      #(atom("procured_at"), dynamic.int(procured_at)),
    ])
  let assert Ok(_) =
    book_procured_v1_to_sqlite_books.handle_event(
      "",
      event,
      dict.new(),
      evoq.empty_state(),
    )
  book_id
}

fn seed_reading(member_id: String, book_id: String, started_at: Int) -> String {
  let reading_id = ids.mint_stream_id("reading")
  let event =
    envelope("reading_started_v1", "evt-q-4", 0, [
      #(atom("reading_id"), dynamic.string(reading_id)),
      #(atom("member_id"), dynamic.string(member_id)),
      #(atom("book_id"), dynamic.string(book_id)),
      #(atom("started_at"), dynamic.int(started_at)),
    ])
  let assert Ok(_) =
    reading_started_v1_to_sqlite_readings.handle_event(
      "",
      event,
      dict.new(),
      evoq.empty_state(),
    )
  reading_id
}

pub fn get_bookclub_by_id_finds_a_seeded_club_test() {
  ensure_stores()
  let club_id = seed_club("The Crooked Shelf", 42)
  let assert Ok(club) = get_bookclub_by_id.find(club_id)
  club.club_id |> should.equal(club_id)
  club.name |> should.equal("The Crooked Shelf")
  club.status
  |> should.equal(bookclub_status.to_string(bookclub_status.initiated()))
  club.initiated_by |> should.equal("bea")
  club.initiated_at |> should.equal(42)
}

pub fn get_bookclub_by_id_says_not_found_for_an_unknown_club_test() {
  ensure_stores()
  get_bookclub_by_id.find(ids.mint_stream_id("bookclub"))
  |> should.equal(Error(atom("not_found")))
}

pub fn get_member_by_id_finds_a_seeded_member_test() {
  ensure_stores()
  let member_id = seed_member("Bea", 200)
  let assert Ok(member) = get_member_by_id.find(member_id)
  member.member_id |> should.equal(member_id)
  member.name |> should.equal("Bea")
  member.status
  |> should.equal(member_status.to_string(member_status.registered()))
  member.registered_at |> should.equal(200)
}

pub fn get_member_by_id_says_not_found_for_an_unknown_member_test() {
  ensure_stores()
  get_member_by_id.find(ids.mint_stream_id("member"))
  |> should.equal(Error(atom("not_found")))
}

pub fn get_book_by_id_finds_a_seeded_book_test() {
  ensure_stores()
  let book_id = seed_book("The Hobbit", "J.R.R. Tolkien", 300)
  let assert Ok(book) = get_book_by_id.find(book_id)
  book.book_id |> should.equal(book_id)
  book.title |> should.equal("The Hobbit")
  book.author |> should.equal("J.R.R. Tolkien")
  book.status |> should.equal(book_status.to_string(book_status.on_shelf()))
  book.procured_at |> should.equal(300)
}

pub fn get_book_by_id_says_not_found_for_an_unknown_book_test() {
  ensure_stores()
  get_book_by_id.find(ids.mint_stream_id("book"))
  |> should.equal(Error(atom("not_found")))
}

pub fn get_reading_by_id_finds_a_seeded_reading_test() {
  ensure_stores()
  let reading_id =
    seed_reading(ids.mint_stream_id("member"), ids.mint_stream_id("book"), 100)
  let assert Ok(reading) = get_reading_by_id.find(reading_id)
  reading.reading_id |> should.equal(reading_id)
  reading.status
  |> should.equal(reading_status.to_string(reading_status.in_progress()))
  reading.started_at |> should.equal(100)
  reading.pages_read |> should.equal(0)
  // A fresh reading has no finished_at: SQL NULL arrives as the atom
  // `undefined`.
  reading.finished_at |> should.equal(option.None)
}

pub fn get_reading_by_id_says_not_found_for_an_unknown_reading_test() {
  ensure_stores()
  get_reading_by_id.find(ids.mint_stream_id("reading"))
  |> should.equal(Error(atom("not_found")))
}

pub fn get_readings_by_member_returns_them_oldest_first_test() {
  ensure_stores()
  let member_id = ids.mint_stream_id("member")
  let _ = seed_reading(member_id, ids.mint_stream_id("book"), 100)
  let _ = seed_reading(member_id, ids.mint_stream_id("book"), 200)
  let assert Ok(readings) = get_readings_by_member.find(member_id)
  readings |> list.length |> should.equal(2)
  let assert [first, second] = readings
  first.started_at |> should.equal(100)
  second.started_at |> should.equal(200)
}

pub fn get_readings_by_member_returns_none_for_a_member_without_readings_test() {
  ensure_stores()
  get_readings_by_member.find(ids.mint_stream_id("member"))
  |> should.equal(Ok([]))
}
