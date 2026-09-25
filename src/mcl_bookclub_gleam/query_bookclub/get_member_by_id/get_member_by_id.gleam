//// get_member_by_id: the member, by their stream id. Typed like the club
//// desk.

import gleam/dict
import gleam/dynamic
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/payload.{type Payload, atom, wrap}
import mcl_bookclub_gleam/query_bookclub/bookclub_query_store

pub type Member {
  Member(
    member_id: String,
    club_id: String,
    name: String,
    status: String,
    registered_at: Int,
  )
}

/// One member, or not_found. The row's cells arrive in SELECT order.
pub fn find(member_id: String) -> Result(Member, dynamic.Dynamic) {
  case
    bookclub_query_store.q(
      "SELECT member_id, club_id, name, status, registered_at FROM members WHERE member_id = ?",
      [dynamic.string(member_id)],
    )
  {
    Ok([[member_id, club_id, name, status, registered_at], ..]) ->
      Ok(Member(
        member_id: desk.cell_string(member_id, "member_id"),
        club_id: desk.cell_string(club_id, "club_id"),
        name: desk.cell_string(name, "name"),
        status: desk.cell_string(status, "status"),
        registered_at: desk.cell_int(registered_at, "registered_at"),
      ))
    Ok([]) -> Error(atom("not_found"))
    Ok(_) -> Error(atom("not_found"))
    Error(reason) -> Error(wrap(#(atom("store_error"), reason)))
  }
}

/// The atom-keyed map form, for the admin UI's JSON replies.
pub fn to_map(member: Member) -> Payload {
  dict.from_list([
    #(atom("member_id"), dynamic.string(member.member_id)),
    #(atom("club_id"), dynamic.string(member.club_id)),
    #(atom("name"), dynamic.string(member.name)),
    #(atom("status"), dynamic.string(member.status)),
    #(atom("registered_at"), dynamic.int(member.registered_at)),
  ])
}
