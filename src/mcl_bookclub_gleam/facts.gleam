//// mcl-bookclub's public contract on the mesh: three facts.
////
////   member_registered_v1 on `<realm>/mcl-bookclub/bookclub/member/member_registered_v1'
////   book_procured_v1    on `<realm>/mcl-bookclub/bookclub/book/book_procured_v1'
////   book_retired_v1     on `<realm>/mcl-bookclub/bookclub/book/book_retired_v1'
////
//// One topic per fact kind; the ids and names are in the payload, not the
//// topic name: a consumer subscribes once and filters. Every fact carries
//// club_id AND club_name -- the club is a payload parameter, never a
//// namespace, which is what lets one topic set serve a thousand clubs.
////
//// The domain event stays internal; what leaves is a FACT on the mesh,
//// and this module is the only place the two shapes meet (the emitter
//// desks translate, nobody else). Text travels as CBOR text, booleans as
//// 1/0.
////
//// This module and the emit_* desks are the ONLY facade modules that name
//// the mesh SDK; the division apps never do.

import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/list
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/mesh
import mcl_bookclub_gleam/internal/payload.{type Payload, atom, wrap}

const org = "mcl-bookclub"

const domain = "bookclub"

const version = 1

/// The three fact kinds: one topic per kind.
pub type FactKind {
  MemberRegistered
  BookProcured
  BookRetired
}

const member_fields = [
  "member_id",
  "club_id",
  "club_name",
  "name",
  "registered_at",
]

const book_fields = [
  "book_id",
  "club_id",
  "club_name",
  "title",
  "author",
  "procured_at",
]

const retired_fields = [
  "book_id",
  "club_id",
  "club_name",
  "title",
  "author",
  "procured_at",
  "retired_by",
  "retired_at",
]

/// The fact for a registered event, whose keys may be atoms or binaries
/// (an event read back from the store is binary-keyed). Read with
/// mcl_om_wire:field/2 -- the tolerant reader the corpus's Demon 65
/// prescribes for anything that may arrive wire-shaped.
pub fn member_registered(event: Payload) -> Payload {
  build(event, member_fields)
}

pub fn book_procured(event: Payload) -> Payload {
  build(event, book_fields)
}

pub fn book_retired(event: Payload) -> Payload {
  build(event, retired_fields)
}

fn build(event: Payload, fields: List(String)) -> Payload {
  dict.from_list(
    list.map(fields, fn(field) {
      #(dynamic.string(field), mesh.field(dynamic.string(field), event))
    }),
  )
}

/// Text as CBOR text, booleans as 1/0, numbers as they are -- applied to
/// one value, or to every value of a fact map.
pub fn to_wire(value: dynamic.Dynamic) -> dynamic.Dynamic {
  case decode.run(value, decode.string) {
    Ok(binary) -> wrap(#(atom("text"), dynamic.string(binary)))
    Error(_) ->
      case decode.run(value, decode.bool) {
        Ok(True) -> dynamic.int(1)
        Ok(False) -> dynamic.int(0)
        Error(_) ->
          case decode.run(value, decode.list(decode.dynamic)) {
            Ok(values) -> dynamic.list(list.map(values, to_wire))
            Error(_) ->
              case desk.decode_map(value) {
                Ok(map) ->
                  desk.payload_to_dynamic(
                    dict.map_values(map, fn(_key, value) { to_wire(value) }),
                  )
                Error(_) -> value
              }
          }
      }
  }
}

/// A whole fact, wire-shaped for publishing.
pub fn to_wire_payload(fact: Payload) -> Payload {
  dict.map_values(fact, fn(_key, value) { to_wire(value) })
}

/// The topic name for a fact kind, in the realm whose name the topics
/// carry: io.macula for this fleet.
pub fn topic(realm_name: String, kind: FactKind) -> String {
  case kind {
    MemberRegistered ->
      mesh.app_fact_topic(
        realm_name,
        org,
        domain,
        "member",
        "member_registered",
        version,
      )
    BookProcured ->
      mesh.app_fact_topic(
        realm_name,
        org,
        domain,
        "book",
        "book_procured",
        version,
      )
    BookRetired ->
      mesh.app_fact_topic(
        realm_name,
        org,
        domain,
        "book",
        "book_retired",
        version,
      )
  }
}

pub fn realm_name() -> String {
  "io.macula"
}
