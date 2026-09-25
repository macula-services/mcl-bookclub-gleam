//// get_member_by_id: the member, by their stream id.

import gleam/dict
import gleam/dynamic
import mcl_bookclub_gleam/internal/payload.{atom, type Payload, wrap}
import mcl_bookclub_gleam/query_bookclub/bookclub_query_store

/// One member, or not_found. The row's cells arrive in SELECT order.
pub fn find(member_id: String) -> Result(Payload, dynamic.Dynamic) {
  found(bookclub_query_store.q(
    "SELECT member_id, club_id, name, status, registered_at FROM members WHERE member_id = ?",
    [dynamic.string(member_id)],
  ))
}

fn found(result: Result(List(List(dynamic.Dynamic)), dynamic.Dynamic)) {
  case result {
    Ok([[member_id, club_id, name, status, registered_at], ..]) -> Ok(dict.from_list([
      #(atom("member_id"), member_id),
      #(atom("club_id"), club_id),
      #(atom("name"), name),
      #(atom("status"), status),
      #(atom("registered_at"), registered_at),
    ]))
    Ok([]) -> Error(atom("not_found"))
    Ok(_) -> Error(atom("not_found"))
    Error(reason) -> Error(wrap(#(atom("store_error"), reason)))
  }
}
