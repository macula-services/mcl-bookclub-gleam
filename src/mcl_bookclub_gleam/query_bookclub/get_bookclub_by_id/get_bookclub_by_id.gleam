//// get_bookclub_by_id: the club, by its stream id.
////
//// A query desk is a pure module answered by the query store: no state,
//// no framework, no mesh. The facade advertises this desk as the mesh
//// capability. The desk returns a TYPED record -- Dynamic lives at the
//// sqlite boundary (the cells), never past it. Banned-name clean:
//// get_{aggregate}_by_id, never list_* or get_all_*.

import gleam/dict
import gleam/dynamic
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/payload.{type Payload, atom, wrap}
import mcl_bookclub_gleam/query_bookclub/bookclub_query_store

pub type Club {
  Club(
    club_id: String,
    name: String,
    status: String,
    initiated_by: String,
    initiated_at: Int,
  )
}

/// One club, or not_found. The row's cells arrive in SELECT order; the
/// schema-contract test keeps that order aligned with the PRJ division's
/// DDL.
pub fn find(club_id: String) -> Result(Club, dynamic.Dynamic) {
  case
    bookclub_query_store.q(
      "SELECT club_id, name, status, initiated_by, initiated_at FROM clubs WHERE club_id = ?",
      [dynamic.string(club_id)],
    )
  {
    Ok([[club_id, name, status, initiated_by, initiated_at], ..]) ->
      Ok(Club(
        club_id: desk.cell_string(club_id, "club_id"),
        name: desk.cell_string(name, "name"),
        status: desk.cell_string(status, "status"),
        initiated_by: desk.cell_string(initiated_by, "initiated_by"),
        initiated_at: desk.cell_int(initiated_at, "initiated_at"),
      ))
    Ok([]) -> Error(atom("not_found"))
    Ok(_) -> Error(atom("not_found"))
    Error(reason) -> Error(wrap(#(atom("store_error"), reason)))
  }
}

/// The atom-keyed map form, for the admin UI's JSON replies.
pub fn to_map(club: Club) -> Payload {
  dict.from_list([
    #(atom("club_id"), dynamic.string(club.club_id)),
    #(atom("name"), dynamic.string(club.name)),
    #(atom("status"), dynamic.string(club.status)),
    #(atom("initiated_by"), dynamic.string(club.initiated_by)),
    #(atom("initiated_at"), dynamic.int(club.initiated_at)),
  ])
}
