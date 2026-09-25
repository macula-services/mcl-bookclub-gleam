//// The PRJ division's boundaries, pinned as mechanisms rather than
//// conventions:
////
//// - no mesh SDK import (internal/mesh, macula, mcl_om, cowboy) in any
////   PRJ source;
//// - no readable-status literal spelled in any PRJ source -- the
////   projections take each status string from the CMD status module's
////   flag map (Demon 68), so only the QUOTED forms count;
//// - every column the QRY desks select is declared by the PRJ division's
////   schema -- bookclub_read_model_store.schema/0 is the only copy of the
////   read model's shape.

import gleam/dynamic
import gleam/dynamic/decode
import gleam/list
import gleam/string
import gleeunit/should
import mcl_bookclub_gleam/test_support
import mcl_bookclub_gleam/project_bookclub/bookclub_read_model_store

/// A source file's text. A raw text decodes directly; file:read_file/1's
/// {ok, Text} arrives as a two-tuple whose element 2 is the text.
fn file_text(content: dynamic.Dynamic) -> String {
  case decode.run(content, decode.string) {
    Ok(text) -> text
    Error(_) -> {
      let assert Ok(text) = decode.run(content, decode.at([1], decode.string))
      text
    }
  }
}

pub fn the_prj_division_imports_no_mesh_sdk_test() {
  let forbidden = ["internal/mesh", "\"macula\"", "mcl_om", "cowboy"]
  test_support.source_files("src/mcl_bookclub_gleam/project_bookclub")
  |> list.each(fn(pair) {
    let #(_, content) = pair
    let text = file_text(content)
    list.each(forbidden, fn(token) {
      string.contains(text, token) |> should.equal(False)
    })
  })
}

pub fn the_prj_division_spells_no_status_literal_test() {
  // Only the QUOTED forms count: the bare words legitimately appear in
  // event-type names ("book_retired_v1") and column names ("finished_at");
  // a status VALUE is always a quoted literal, and the projections must
  // never spell one -- they derive it from the CMD status module (Demon
  // 68).
  let literals = [
    "\"active\"",
    "\"archived\"",
    "\"unregistered\"",
    "\"on_shelf\"",
    "\"retired\"",
    "\"in_progress\"",
    "\"finished\"",
  ]
  test_support.source_files("src/mcl_bookclub_gleam/project_bookclub")
  |> list.each(fn(pair) {
    let #(_, content) = pair
    let text = file_text(content)
    list.each(literals, fn(literal) {
      string.contains(text, literal) |> should.equal(False)
    })
  })
}

pub fn the_query_columns_are_all_in_the_prj_schema_test() {
  // The SELECT column lists the QRY desks use, table by table -- the
  // schema-contract between the two divisions. Every column must be
  // declared by the PRJ schema (the schema is the only copy of the shape),
  // and every desk's own source must name each column of its table (a
  // column a desk does not select would not appear).
  let schema_text = bookclub_read_model_store.schema() |> string.join(" ")
  let tables = [
    #(
      "clubs",
      ["get_bookclub_by_id"],
      ["club_id", "name", "status", "initiated_by", "initiated_at"],
    ),
    #(
      "members",
      ["get_member_by_id"],
      ["member_id", "club_id", "name", "status", "registered_at"],
    ),
    #(
      "books",
      ["get_book_by_id"],
      ["book_id", "club_id", "title", "author", "status", "procured_at"],
    ),
    #(
      "readings",
      ["get_reading_by_id", "get_readings_by_member"],
      [
        "reading_id",
        "member_id",
        "book_id",
        "status",
        "started_at",
        "pages_read",
        "finished_at",
      ],
    ),
  ]
  let qry_sources = test_support.source_files("src/mcl_bookclub_gleam/query_bookclub")
  list.each(tables, fn(table) {
    let #(_, desk_names, columns) = table
    list.each(columns, fn(column) {
      string.contains(schema_text, column) |> should.equal(True)
    })
    list.each(desk_names, fn(desk_name) {
      let desk_files =
        list.filter(qry_sources, fn(pair) {
          let #(path, _) = pair
          string.contains(path, desk_name)
        })
      desk_files |> list.length |> should.equal(1)
      list.each(desk_files, fn(pair) {
        let #(_, content) = pair
        let text = file_text(content)
        list.each(columns, fn(column) {
          string.contains(text, column) |> should.equal(True)
        })
      })
    })
  })
}
