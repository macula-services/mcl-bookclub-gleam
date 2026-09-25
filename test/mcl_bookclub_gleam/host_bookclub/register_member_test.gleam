//// register_member and unregister_member against a real reckon-db store
//// through evoq.
////
//// The store is opened by test_support with the same call the facade's
//// boot makes for this service.

import gleam/dict
import gleam/dynamic
import gleeunit/should
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/payload.{atom}
import mcl_bookclub_gleam/test_support
import mcl_bookclub_gleam/host_bookclub/initiate_bookclub/initiate_bookclub_api
import mcl_bookclub_gleam/host_bookclub/member_state
import mcl_bookclub_gleam/host_bookclub/member_status
import mcl_bookclub_gleam/host_bookclub/register_member/maybe_register_member
import mcl_bookclub_gleam/host_bookclub/register_member/register_member_v1
import mcl_bookclub_gleam/host_bookclub/unregister_member/maybe_unregister_member
import mcl_bookclub_gleam/host_bookclub/unregister_member/unregister_member_v1

/// Initiate a club through the real entry point and return its id.
fn initiated_club() -> String {
  let params = dict.from_list([
    #(atom("name"), dynamic.string("The Reading Circle")),
    #(atom("initiated_by"), dynamic.string("raf")),
  ])
  let assert Ok(#(0, [event])) = initiate_bookclub_api.handle(params)
  desk.get_string(event, "club_id")
  |> should.be_ok
  let assert Ok(club_id) = desk.get_string(event, "club_id")
  club_id
}

fn member(club_id: String, name: String) -> Result(register_member_v1.RegisterMember, dynamic.Dynamic) {
  register_member_v1.new(dict.from_list([
    #(atom("member_id"), dynamic.string(register_member_v1.mint_member_id())),
    #(atom("club_id"), dynamic.string(club_id)),
    #(atom("name"), dynamic.string(name)),
  ]))
}

pub fn a_member_is_registered_on_its_own_stream_test() {
  test_support.run(fn() {
    let club_id = initiated_club()
    let assert Ok(command) = member(club_id, "Bea")
    let assert Ok(#(0, [event])) = maybe_register_member.dispatch(command)
    desk.get_string(event, "name") |> should.equal(Ok("Bea"))
    desk.get_string(event, "club_id") |> should.equal(Ok(club_id))
    let stream = test_support.read_stream(
      test_support.store_id(),
      register_member_v1.stream_id(command),
    )
    let assert [#("member_registered_v1", data), ..] = stream
    let assert Ok(data_map) = desk.decode_map(data)
    desk.get_string(data_map, "name") |> should.equal(Ok("Bea"))
  })
}

pub fn a_second_registration_is_refused_test() {
  test_support.run(fn() {
    let club_id = initiated_club()
    let assert Ok(command) = member(club_id, "Bea")
    let assert Ok(_) = maybe_register_member.dispatch(command)
    maybe_register_member.dispatch(command)
    |> should.equal(Error(atom("already_registered")))
  })
}

pub fn a_registered_member_is_unregistered_test() {
  test_support.run(fn() {
    let club_id = initiated_club()
    let assert Ok(command) = member(club_id, "Bea")
    let assert Ok(_) = maybe_register_member.dispatch(command)
    let member_id = register_member_v1.stream_id(command)
    let assert Ok(unregister) =
      unregister_member_v1.new(dict.from_list([
        #(atom("member_id"), dynamic.string(member_id)),
        #(atom("unregistered_by"), dynamic.string("raf")),
      ]))
    let assert Ok(#(1, _)) = maybe_unregister_member.dispatch(unregister)
    let stream = test_support.read_stream(test_support.store_id(), member_id)
    let assert [#(_, _), #("member_unregistered_v1", data), ..] = stream
    let assert Ok(data_map) = desk.decode_map(data)
    desk.get_string(data_map, "name") |> should.equal(Ok("Bea"))
    desk.get_string(data_map, "club_id") |> should.equal(Ok(club_id))
    desk.get_string(data_map, "unregistered_by") |> should.equal(Ok("raf"))
  })
}

/// The aggregate's blanket lifecycle guard: once unregistered, EVERY
/// command on the stream is refused -- registering again included.
pub fn an_unregistered_member_refuses_every_command_test() {
  test_support.run(fn() {
    let club_id = initiated_club()
    let assert Ok(command) = member(club_id, "Bea")
    let assert Ok(_) = maybe_register_member.dispatch(command)
    let member_id = register_member_v1.stream_id(command)
    let assert Ok(unregister) =
      unregister_member_v1.new(dict.from_list([
        #(atom("member_id"), dynamic.string(member_id)),
        #(atom("unregistered_by"), dynamic.string("raf")),
      ]))
    let assert Ok(_) = maybe_unregister_member.dispatch(unregister)
    maybe_register_member.dispatch(command)
    |> should.equal(Error(atom("unregistered")))
    maybe_unregister_member.dispatch(unregister)
    |> should.equal(Error(atom("unregistered")))
  })
}

pub fn an_unborn_member_cannot_be_unregistered_test() {
  test_support.run(fn() {
    let assert Ok(unregister) =
      unregister_member_v1.new(dict.from_list([
        #(atom("member_id"), dynamic.string(register_member_v1.mint_member_id())),
        #(atom("unregistered_by"), dynamic.string("raf")),
      ]))
    maybe_unregister_member.dispatch(unregister)
    |> should.equal(Error(atom("not_registered")))
  })
}

/// Demon 67: the desk validates BEFORE dispatch, so a rejected stream id
/// never touches the store.
pub fn a_rejected_stream_id_never_touches_the_store_test() {
  test_support.run(fn() {
    let assert Ok(command) =
      register_member_v1.new(dict.from_list([
        #(atom("member_id"), dynamic.string("bea-the-member")),
        #(atom("club_id"), dynamic.string(register_member_v1.mint_member_id())),
        #(atom("name"), dynamic.string("Bea")),
      ]))
    let assert Error(_) = maybe_register_member.dispatch(command)
    Nil
  })
}

pub fn a_command_needs_every_field_test() {
  register_member_v1.new(dict.new())
  |> should.equal(Error(desk.missing_required_fields()))
}

pub fn the_state_folds_both_events_test() {
  let member_id = "member-test"
  let state =
    member_state.new(member_id)
    |> member_state.apply_event(dict.from_list([
      #(atom("event_type"), dynamic.string("member_registered_v1")),
      #(atom("club_id"), dynamic.string("club-a")),
      #(atom("name"), dynamic.string("Bea")),
      #(atom("registered_at"), dynamic.int(1000)),
    ]))
  state |> member_state.is_registered |> should.be_true
  let state2 =
    member_state.apply_event(state, dict.from_list([
      #(atom("event_type"), dynamic.string("member_unregistered_v1")),
    ]))
  state2 |> member_state.is_unregistered |> should.be_true
}

/// The status flag map renders through evoq's own conversion (Demon 68).
pub fn the_status_renders_readable_test() {
  member_status.to_string(member_status.registered())
  |> should.equal("active")
  member_status.to_string(member_status.unregistered())
  |> should.equal("unregistered")
}
