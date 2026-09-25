//// The PRJ division's sqlite store: one actor owning one esqlite
//// connection.
////
//// A NIF connection belongs to the process that opened it, so every write
//// goes through this actor. The DDL lives here and ONLY here -- the QRY
//// division reads the schema this module creates, and a schema-contract
//// test pins the columns QRY selects to the columns this module declares.
////
//// All writes are single statements. A projected event is one INSERT OR
//// REPLACE: atomic by itself, idempotent by construction, which is what
//// makes replays safe.
////
//// The actor answers three messages: Exec (parameterised write), Query
//// (parameterised read, tests and inspection) and Ping (the health
//// probe). Exec and Query reply through the caller's subject; Ping is the
//// raw-ref protocol the FFI's safe_ping/2 speaks -- gleam actors are not
//// gen_servers, so the twins' gen_server ping has this actor-shaped
//// equivalent.

import gleam/dynamic
import gleam/erlang/process
import gleam/otp/actor
import mcl_bookclub_gleam/internal/esqlite
import mcl_bookclub_gleam/internal/health
import mcl_bookclub_gleam/internal/payload

pub type Message {
  Exec(
    sql: String,
    args: List(dynamic.Dynamic),
    reply_to: process.Subject(Result(Nil, dynamic.Dynamic)),
  )
  Query(
    sql: String,
    args: List(dynamic.Dynamic),
    reply_to: process.Subject(Result(List(List(dynamic.Dynamic)), dynamic.Dynamic)),
  )
  Ping(reply_to: #(process.Pid, dynamic.Dynamic))
}

pub type State {
  State(conn: dynamic.Dynamic)
}

/// The schema, in creation order. The one place the read model's shape is
/// written down.
pub fn schema() -> List(String) {
  [
    "CREATE TABLE IF NOT EXISTS clubs ("
    <> " club_id      TEXT PRIMARY KEY,"
    <> " name         TEXT NOT NULL,"
    <> " status       TEXT NOT NULL,"
    <> " initiated_by TEXT NOT NULL,"
    <> " initiated_at INTEGER NOT NULL,"
    <> " event_id     TEXT NOT NULL,"
    <> " version      INTEGER NOT NULL)",
    "CREATE TABLE IF NOT EXISTS members ("
    <> " member_id     TEXT PRIMARY KEY,"
    <> " club_id       TEXT NOT NULL,"
    <> " name          TEXT NOT NULL,"
    <> " status        TEXT NOT NULL,"
    <> " registered_at INTEGER NOT NULL,"
    <> " event_id      TEXT NOT NULL,"
    <> " version       INTEGER NOT NULL)",
    "CREATE TABLE IF NOT EXISTS books ("
    <> " book_id      TEXT PRIMARY KEY,"
    <> " club_id      TEXT NOT NULL,"
    <> " title        TEXT NOT NULL,"
    <> " author       TEXT NOT NULL,"
    <> " status       TEXT NOT NULL,"
    <> " procured_at  INTEGER NOT NULL,"
    <> " event_id     TEXT NOT NULL,"
    <> " version      INTEGER NOT NULL)",
    "CREATE TABLE IF NOT EXISTS readings ("
    <> " reading_id  TEXT PRIMARY KEY,"
    <> " member_id   TEXT NOT NULL,"
    <> " book_id     TEXT NOT NULL,"
    <> " status      TEXT NOT NULL,"
    <> " started_at  INTEGER NOT NULL,"
    <> " pages_read  INTEGER NOT NULL,"
    <> " finished_at INTEGER,"
    <> " event_id    TEXT NOT NULL,"
    <> " version     INTEGER NOT NULL)",
  ]
}

/// The registered actor name -- health pings it, the caller-side wrappers
/// address it.
pub fn name() -> dynamic.Dynamic {
  payload.atom("bookclub_read_model_store")
}

/// Start the store actor, registered under its name, owning the sqlite
/// connection opened in its own process.
pub fn start(
  sqlite_path: String,
) -> Result(actor.Started(process.Subject(Message)), actor.StartError) {
  actor.new_with_initialiser(10_000, fn(subject) { init_store(sqlite_path, subject) })
  |> actor.on_message(handle_message)
  |> actor.named(process.new_name("bookclub_read_model_store"))
  |> actor.start
}

fn init_store(
  sqlite_path: String,
  subject: process.Subject(Message),
) -> Result(actor.Initialised(State, Message, process.Subject(Message)), String) {
  case esqlite.ensure_dir(sqlite_path) {
    Ok(_) ->
      case esqlite.open(sqlite_path) {
        Ok(conn) ->
          case create_schema(conn, schema()) {
            Ok(_) -> Ok(actor.initialised(State(conn)) |> actor.returning(subject))
            Error(_) -> Error("schema_failed")
          }
        Error(_) -> Error("open_failed")
      }
    Error(_) -> Error("ensure_dir_failed")
  }
}

fn create_schema(conn: dynamic.Dynamic, statements: List(String)) -> Result(Nil, dynamic.Dynamic) {
  case statements {
    [] -> Ok(Nil)
    [sql, ..rest] ->
      case esqlite.exec(conn, sql, []) {
        Ok(_) -> create_schema(conn, rest)
        Error(e) -> Error(e)
      }
  }
}

fn handle_message(state: State, message: Message) -> actor.Next(State, Message) {
  case message {
    Exec(sql, args, reply_to) -> {
      process.send(reply_to, esqlite.exec(state.conn, sql, args))
      actor.continue(state)
    }
    Query(sql, args, reply_to) -> {
      process.send(reply_to, esqlite.q(state.conn, sql, args))
      actor.continue(state)
    }
    Ping(reply_to) -> {
      health.send_reply(reply_to, health.ok_reply())
      actor.continue(state)
    }
  }
}

/// The caller-side subject: resolves the registered name at send time.
pub fn subject() -> process.Subject(Message) {
  process.named_subject(process.new_name("bookclub_read_model_store"))
}

/// One parameterised write through the store actor. A projection turns an
/// Error into {store_error, Reason} and evoq's retry machinery takes over
/// -- a store error is a retryable condition, never a crash.
pub fn exec(sql: String, args: List(dynamic.Dynamic)) -> Result(Nil, dynamic.Dynamic) {
  actor.call(subject(), 5000, fn(reply_to) { Exec(sql, args, reply_to) })
}

/// One parameterised read, for tests and inspection.
pub fn q(
  sql: String,
  args: List(dynamic.Dynamic),
) -> Result(List(List(dynamic.Dynamic)), dynamic.Dynamic) {
  actor.call(subject(), 5000, fn(reply_to) { Query(sql, args, reply_to) })
}
