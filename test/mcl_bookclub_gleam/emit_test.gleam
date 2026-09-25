//// The emitters' declared contract: skip on replay (a restart must not
//// re-publish history), the single interest each, and the fact payload's
//// wire shape (text as CBOR text) -- the same assertions the Erlang
//// twin's emitter suite makes (see
//// emit_member_registered_v1_to_mesh_tests.erl).

import gleam/dict
import gleam/dynamic
import gleeunit/should
import mcl_bookclub_gleam/emit_book_procured_v1_to_mesh
import mcl_bookclub_gleam/emit_book_retired_v1_to_mesh
import mcl_bookclub_gleam/emit_member_registered_v1_to_mesh
import mcl_bookclub_gleam/facts
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/evoq
import mcl_bookclub_gleam/internal/payload.{atom, wrap}

/// A side-effect handler must refuse replays, or a restart re-publishes
/// the whole history. The mechanism is the declared policy, asserted so
/// a dropped declaration breaks a test.
pub fn the_emitters_declare_skip_and_their_interests_test() {
  emit_member_registered_v1_to_mesh.interested_in()
  |> should.equal(["member_registered_v1"])
  emit_member_registered_v1_to_mesh.replay_policy()
  |> should.equal(evoq.replay_skip())
  emit_member_registered_v1_to_mesh.init(dict.new())
  |> should.equal(Ok(evoq.empty_state()))

  emit_book_procured_v1_to_mesh.interested_in()
  |> should.equal(["book_procured_v1"])
  emit_book_procured_v1_to_mesh.replay_policy()
  |> should.equal(evoq.replay_skip())
  emit_book_procured_v1_to_mesh.init(dict.new())
  |> should.equal(Ok(evoq.empty_state()))

  emit_book_retired_v1_to_mesh.interested_in()
  |> should.equal(["book_retired_v1"])
  emit_book_retired_v1_to_mesh.replay_policy()
  |> should.equal(evoq.replay_skip())
  emit_book_retired_v1_to_mesh.init(dict.new())
  |> should.equal(Ok(evoq.empty_state()))
}

/// The fact a consumer receives: text as CBOR text, numbers as they are.
pub fn the_fact_payload_matches_the_wire_contract_test() {
  let event =
    dict.from_list([
      #(atom("event_type"), dynamic.string("member_registered_v1")),
      #(atom("member_id"), dynamic.string("member-1")),
      #(atom("club_id"), dynamic.string("club-1")),
      #(atom("club_name"), dynamic.string("The Club")),
      #(atom("name"), dynamic.string("Bea")),
      #(atom("registered_at"), dynamic.int(1000)),
    ])
  let fact = facts.to_wire_payload(facts.member_registered(event))
  desk.get(fact, "club_name")
  |> should.equal(Ok(wrap(#(atom("text"), dynamic.string("The Club")))))
  desk.get(fact, "name")
  |> should.equal(Ok(wrap(#(atom("text"), dynamic.string("Bea")))))
  desk.get(fact, "member_id")
  |> should.equal(Ok(wrap(#(atom("text"), dynamic.string("member-1")))))
  desk.get(fact, "registered_at")
  |> should.equal(Ok(dynamic.int(1000)))
}
