//// The QRY division's sqlite store: one actor owning one esqlite
//// connection.
////
//// READ-ONLY BY API: only q/2 is exposed, so a query desk cannot write
//// and a write path can never slip into the read division. The schema
//// itself is owned by the PRJ division
//// (bookclub_read_model_store.schema/0); this process opens the same file
//// and assumes that schema exists. A schema-contract test pins the
//// columns the query desks select to the columns PRJ declares, so the two
//// sides cannot drift apart silently.

import gleam/dynamic
import gleam/erlang/process
import gleam/otp/actor
import mcl_bookclub_gleam/internal/esqlite
import mcl_bookclub_gleam/internal/health
import mcl_bookclub_gleam/internal/payload.{atom}

pub type Message {
  Query(
    sql: String,
    args: List(dynamic.Dynamic),
    reply_to: process.Subject(
      Result(List(List(dynamic.Dynamic)), dynamic.Dynamic),
    ),
  )
  Ping(reply_to: #(process.Pid, dynamic.Dynamic))
}

pub type State {
  State(conn: dynamic.Dynamic)
}

/// The registered actor name -- health pings it, the caller-side wrapper
/// addresses it.
pub fn name() -> dynamic.Dynamic {
  atom("bookclub_query_store")
}

/// Start the store actor, registered under its name, owning the sqlite
/// connection opened in its own process.
pub fn start(
  sqlite_path: String,
) -> Result(actor.Started(process.Subject(Message)), actor.StartError) {
  actor.new_with_initialiser(10_000, fn(subject) {
    init_store(sqlite_path, subject)
  })
  |> actor.on_message(handle_message)
  |> actor.named(health.exact_name("bookclub_query_store"))
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
          Ok(actor.initialised(State(conn)) |> actor.returning(subject))
        Error(_) -> Error("open_failed")
      }
    Error(_) -> Error("ensure_dir_failed")
  }
}

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  case message {
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
  process.named_subject(health.exact_name("bookclub_query_store"))
}

/// One parameterised read: rows as lists of cells in SELECT order, or
/// {error, Reason} -- which the desks surface as {store_error, _}.
pub fn q(
  sql: String,
  args: List(dynamic.Dynamic),
) -> Result(List(List(dynamic.Dynamic)), dynamic.Dynamic) {
  actor.call(subject(), 5000, fn(reply_to) { Query(sql, args, reply_to) })
}
