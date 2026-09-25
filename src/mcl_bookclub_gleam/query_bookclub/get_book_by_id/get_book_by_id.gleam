//// get_book_by_id: the book, by its stream id. Typed like the club desk.

import gleam/dict
import gleam/dynamic
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/payload.{type Payload, atom, wrap}
import mcl_bookclub_gleam/query_bookclub/bookclub_query_store

pub type Book {
  Book(
    book_id: String,
    club_id: String,
    title: String,
    author: String,
    status: String,
    procured_at: Int,
  )
}

/// One book, or not_found. The row's cells arrive in SELECT order.
pub fn find(book_id: String) -> Result(Book, dynamic.Dynamic) {
  case
    bookclub_query_store.q(
      "SELECT book_id, club_id, title, author, status, procured_at FROM books WHERE book_id = ?",
      [dynamic.string(book_id)],
    )
  {
    Ok([[book_id, club_id, title, author, status, procured_at], ..]) ->
      Ok(Book(
        book_id: desk.cell_string(book_id, "book_id"),
        club_id: desk.cell_string(club_id, "club_id"),
        title: desk.cell_string(title, "title"),
        author: desk.cell_string(author, "author"),
        status: desk.cell_string(status, "status"),
        procured_at: desk.cell_int(procured_at, "procured_at"),
      ))
    Ok([]) -> Error(atom("not_found"))
    Ok(_) -> Error(atom("not_found"))
    Error(reason) -> Error(wrap(#(atom("store_error"), reason)))
  }
}

/// The atom-keyed map form, for the admin UI's JSON replies.
pub fn to_map(book: Book) -> Payload {
  dict.from_list([
    #(atom("book_id"), dynamic.string(book.book_id)),
    #(atom("club_id"), dynamic.string(book.club_id)),
    #(atom("title"), dynamic.string(book.title)),
    #(atom("author"), dynamic.string(book.author)),
    #(atom("status"), dynamic.string(book.status)),
    #(atom("procured_at"), dynamic.int(book.procured_at)),
  ])
}
