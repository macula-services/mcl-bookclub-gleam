//// The facts module's wire contract, pinned: the three fact kinds carry
//// the wire fields, text travels as CBOR text, booleans as 1/0, and one
//// topic names each fact kind with the ids in the payload -- the same
//// shapes the Erlang twin's emitter suite asserts (see
//// emit_member_registered_v1_to_mesh_tests.erl).

import gleam/dict
import gleam/dynamic
import gleeunit/should
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/payload.{atom, wrap}
import mcl_bookclub_gleam/facts

fn member_event() -> dict.Dict(dynamic.Dynamic, dynamic.Dynamic) {
  dict.from_list([
    #(atom("event_type"), dynamic.string("member_registered_v1")),
    #(atom("member_id"), dynamic.string("member-1")),
    #(atom("club_id"), dynamic.string("club-1")),
    #(atom("club_name"), dynamic.string("The Club")),
    #(atom("name"), dynamic.string("Bea")),
    #(atom("registered_at"), dynamic.int(1000)),
  ])
}

fn procured_event() -> dict.Dict(dynamic.Dynamic, dynamic.Dynamic) {
  dict.from_list([
    #(atom("event_type"), dynamic.string("book_procured_v1")),
    #(atom("book_id"), dynamic.string("book-1")),
    #(atom("club_id"), dynamic.string("club-1")),
    #(atom("club_name"), dynamic.string("The Club")),
    #(atom("title"), dynamic.string("Persuasion")),
    #(atom("author"), dynamic.string("Austen")),
    #(atom("procured_at"), dynamic.int(1000)),
  ])
}

fn retired_event() -> dict.Dict(dynamic.Dynamic, dynamic.Dynamic) {
  dict.from_list([
    #(atom("event_type"), dynamic.string("book_retired_v1")),
    #(atom("book_id"), dynamic.string("book-1")),
    #(atom("club_id"), dynamic.string("club-1")),
    #(atom("club_name"), dynamic.string("The Club")),
    #(atom("title"), dynamic.string("Persuasion")),
    #(atom("author"), dynamic.string("Austen")),
    #(atom("procured_at"), dynamic.int(1000)),
    #(atom("retired_by"), dynamic.string("raf")),
    #(atom("retired_at"), dynamic.int(2000)),
  ])
}

/// The five wire fields, present and readable. mesh.field unwraps CBOR
/// text, so a plain binary event value stays a plain binary.
pub fn the_member_fact_carries_the_wire_fields_test() {
  let fact = facts.member_registered(member_event())
  desk.get(fact, "member_id") |> should.be_ok
  desk.get(fact, "club_id") |> should.be_ok
  desk.get(fact, "club_name") |> should.be_ok
  desk.get(fact, "name") |> should.be_ok
  desk.get(fact, "registered_at") |> should.be_ok
  desk.get_string(fact, "member_id") |> should.equal(Ok("member-1"))
  desk.get_string(fact, "club_id") |> should.equal(Ok("club-1"))
  desk.get_string(fact, "club_name") |> should.equal(Ok("The Club"))
  desk.get_string(fact, "name") |> should.equal(Ok("Bea"))
}

/// Six fields for a procured book, eight for a retired one (the retired
/// fact echoes procured_at, so a consumer's retire write can REPLACE the
/// whole row).
pub fn the_book_facts_carry_the_wire_fields_test() {
  let procured = facts.book_procured(procured_event())
  desk.get(procured, "book_id") |> should.be_ok
  desk.get(procured, "club_id") |> should.be_ok
  desk.get(procured, "club_name") |> should.be_ok
  desk.get(procured, "title") |> should.be_ok
  desk.get(procured, "author") |> should.be_ok
  desk.get(procured, "procured_at") |> should.be_ok
  desk.get_string(procured, "title") |> should.equal(Ok("Persuasion"))
  desk.get_string(procured, "author") |> should.equal(Ok("Austen"))

  let retired = facts.book_retired(retired_event())
  desk.get(retired, "book_id") |> should.be_ok
  desk.get(retired, "club_id") |> should.be_ok
  desk.get(retired, "club_name") |> should.be_ok
  desk.get(retired, "title") |> should.be_ok
  desk.get(retired, "author") |> should.be_ok
  desk.get(retired, "procured_at") |> should.be_ok
  desk.get(retired, "retired_by") |> should.be_ok
  desk.get(retired, "retired_at") |> should.be_ok
  desk.get_string(retired, "retired_by") |> should.equal(Ok("raf"))
  desk.get_string(retired, "title") |> should.equal(Ok("Persuasion"))
}

pub fn the_wire_shapes_text_as_cbor_text_test() {
  facts.to_wire(dynamic.string("hello"))
  |> should.equal(wrap(#(atom("text"), dynamic.string("hello"))))
}

pub fn the_wire_shapes_booleans_as_one_and_zero_test() {
  facts.to_wire(dynamic.bool(True)) |> should.equal(dynamic.int(1))
  facts.to_wire(dynamic.bool(False)) |> should.equal(dynamic.int(0))
}

pub fn the_wire_shapes_maps_recursively_test() {
  facts.to_wire(dynamic.properties([
    #(dynamic.string("a"), dynamic.string("b")),
  ]))
  |> should.equal(dynamic.properties([
    #(dynamic.string("a"), wrap(#(atom("text"), dynamic.string("b")))),
  ]))
  let result =
    facts.to_wire_payload(dict.from_list([
      #(atom("k"), dynamic.string("v")),
    ]))
  desk.get(result, "k")
  |> should.equal(Ok(wrap(#(atom("text"), dynamic.string("v")))))
}

/// One topic per fact kind, in the realm whose name the topics carry --
/// the strings the twins publish on, verbatim.
pub fn the_topics_name_the_three_fact_kinds_test() {
  facts.realm_name()
  |> should.equal("io.macula")
  facts.topic(facts.realm_name(), facts.MemberRegistered)
  |> should.equal("io.macula/mcl-bookclub/bookclub/member/member_registered_v1")
  facts.topic(facts.realm_name(), facts.BookProcured)
  |> should.equal("io.macula/mcl-bookclub/bookclub/book/book_procured_v1")
  facts.topic(facts.realm_name(), facts.BookRetired)
  |> should.equal("io.macula/mcl-bookclub/bookclub/book/book_retired_v1")
}
