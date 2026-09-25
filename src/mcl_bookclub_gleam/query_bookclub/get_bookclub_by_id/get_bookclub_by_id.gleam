//// get_bookclub_by_id: the club, by its stream id.
////
//// A query desk is a pure module answered by the query store: no state,
//// no framework, no mesh. The facade advertises this desk as the mesh
//// capability. Banned-name clean: get_{aggregate}_by_id, never list_* or
//// get_all_*.

import gleam/dict
import gleam/dynamic
import mcl_bookclub_gleam/internal/payload.{type Payload, atom, wrap}
import mcl_bookclub_gleam/query_bookclub/bookclub_query_store

/// One club, or not_found. The row's cells arrive in SELECT order; the
/// schema-contract test keeps that order aligned with the PRJ division's
/// DDL.
pub fn find(club_id: String) -> Result(Payload, dynamic.Dynamic) {
  found(
    bookclub_query_store.q(
      "SELECT club_id, name, status, initiated_by, initiated_at FROM clubs WHERE club_id = ?",
      [dynamic.string(club_id)],
    ),
  )
}

fn found(result: Result(List(List(dynamic.Dynamic)), dynamic.Dynamic)) {
  case result {
    Ok([[club_id, name, status, initiated_by, initiated_at], ..]) ->
      Ok(
        dict.from_list([
          #(atom("club_id"), club_id),
          #(atom("name"), name),
          #(atom("status"), status),
          #(atom("initiated_by"), initiated_by),
          #(atom("initiated_at"), initiated_at),
        ]),
      )
    Ok([]) -> Error(atom("not_found"))
    Ok(_) -> Error(atom("not_found"))
    Error(reason) -> Error(wrap(#(atom("store_error"), reason)))
  }
}
