//// The real delivery path: a member registration dispatched through the
//// reckon-db store rides the $all subscription into the evoq router, the
//// member_registered projection handler writes the members row through
//// the shared read-model store actor, and the row appears -- no direct
//// handle_event call anywhere in this test.

import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/int
import gleeunit/should
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/evoq
import mcl_bookclub_gleam/internal/payload.{atom, new, wrap}
import mcl_bookclub_gleam/test_support
import mcl_bookclub_gleam/host_bookclub/initiate_bookclub/initiate_bookclub_api
import mcl_bookclub_gleam/host_bookclub/register_member/register_member_api
import mcl_bookclub_gleam/project_bookclub/bookclub_read_model_store

/// Start the store actor on a unique path and ignore the error: the first
/// caller in the VM wins the fixed name and creates the schema; later
/// tests reuse whatever connection exists.
fn ensure_store_actor() -> Nil {
  let _ = bookclub_read_model_store.start(
    "/tmp/mcl_bookclub_gleam_prj_tests/"
    <> int.to_string(test_support.unique_integer([wrap(atom("positive"))]))
    <> "/bookclub.sqlite3",
  )
  Nil
}

pub fn a_member_registration_is_projected_through_the_subscription_test() {
  test_support.run(fn() {
    ensure_store_actor()
    // The projection handler, as the PRJ supervisor starts it: the evoq
    // handler registers itself for member_registered_v1 and delivers into
    // the shared store actor.
    let _ =
      evoq.handler_start(
        atom(
          "mcl_bookclub_gleam@project_bookclub@member_registered@member_registered_v1_to_sqlite_members",
        ),
        new(),
      )
    // A real club, then a real member, through the real entry points --
    // the events flow through the store subscription, not through any
    // direct handle_event call.
    let assert Ok(#(_, [club_event])) =
      initiate_bookclub_api.handle(dict.from_list([
        #(atom("name"), dynamic.string("The Reading Circle")),
        #(atom("initiated_by"), dynamic.string("raf")),
      ]))
    let assert Ok(club_id) = desk.get_string(club_event, "club_id")
    let assert Ok(#(_, [member_event])) =
      register_member_api.handle(dict.from_list([
        #(atom("club_id"), dynamic.string(club_id)),
        #(atom("name"), dynamic.string("Bea")),
      ]))
    let assert Ok(member_id) = desk.get_string(member_event, "member_id")
    await_member_name(member_id, 100)
    |> should.equal("Bea")
  })
}

/// Poll the members table until the projected row shows up (delivery is
/// asynchronous), or give up after `tries` attempts.
fn await_member_name(member_id: String, tries: Int) -> String {
  let result =
    bookclub_read_model_store.q(
      "SELECT name FROM members WHERE member_id = ?",
      [dynamic.string(member_id)],
    )
  case result {
    Ok([[name], ..]) -> {
      let assert Ok(name) = decode.run(name, decode.string)
      name
    }
    _ ->
      case tries > 0 {
        True -> {
          process.sleep(100)
          await_member_name(member_id, tries - 1)
        }
        False -> ""
      }
  }
}
