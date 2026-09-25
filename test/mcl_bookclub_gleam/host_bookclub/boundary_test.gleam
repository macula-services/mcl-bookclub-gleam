//// The CMD division boundary, as a mechanism rather than a convention: the
//// host_bookclub sources must not name the mesh SDK, the read-model store,
//// or the web layer -- not even in prose, because naming the thing in a
//// comment is how the drift starts. The emitters and the facts module, the
//// named places where the domain meets the mesh, live in the facade
//// division, so EVERY file under host_bookclub is held to the check.
////
//// The tokens are spelled the way an @external reference would: the mesh
//// import path, the macula and cowboy module names as quoted literals, and
//// the mcl_om/esqlite/cowboy_req module names bare. The bare word "cowboy"
//// is deliberately NOT checked: the division's own moduledocs say
//// "no cowboy, no mesh", and a boundary test must not trip the division's
//// own house prose -- a quoted `"cowboy"` reference or a bare cowboy_req
//// still refuses.

import gleam/dynamic
import gleam/dynamic/decode
import gleam/list
import gleam/string
import mcl_bookclub_gleam/test_support

/// The FFI hands back file:read_file/1's tuple (`{ok, Binary}` |
/// `{error, Reason}`) wrapped in a Dynamic, so the binary is lifted out of
/// the tuple's second slot before decoding it as text.
@external(erlang, "erlang", "element")
fn tuple_element(index: Int, tuple: dynamic.Dynamic) -> dynamic.Dynamic

/// Decode a source file's content: a bare binary decodes directly; the
/// `{ok, Binary}` read tuple is unwrapped first.
fn content_text(content: dynamic.Dynamic) -> Result(String, Nil) {
  case decode.run(content, decode.string) {
    Ok(text) -> Ok(text)
    Error(_) ->
      case decode.run(tuple_element(2, content), decode.string) {
        Ok(text) -> Ok(text)
        Error(_) -> Error(Nil)
      }
  }
}

/// The references the CMD division may not carry.
fn forbidden_tokens() -> List(String) {
  [
    "internal/mesh",
    "\"macula\"",
    "mcl_om",
    "esqlite",
    "\"cowboy\"",
    "cowboy_req",
  ]
}

/// Every forbidden token must be absent from the file's text; the first
/// hit is refused with the path and the token it found.
fn assert_clean(path: String, text: String) -> Nil {
  case
    list.find_map(forbidden_tokens(), fn(token) {
      case string.contains(text, token) {
        True -> Ok(token)
        False -> Error(Nil)
      }
    })
  {
    Error(_) -> Nil
    Ok(token) -> panic as { "forbidden reference in " <> path <> ": " <> token }
  }
}

pub fn the_cmd_division_imports_no_mesh_sdk_test() {
  test_support.source_files("src/mcl_bookclub_gleam/host_bookclub")
  |> list.each(fn(pair) {
    let #(path, content) = pair
    case content_text(content) {
      Ok(text) -> assert_clean(path, text)
      Error(_) -> panic as { "unreadable source file: " <> path }
    }
  })
}
