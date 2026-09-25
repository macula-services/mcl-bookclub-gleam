//// archive_bookclub_api: the HTTP entry point for archive_bookclub_v1.
////
//// Pure, like every entry point here: params in, dispatch result out. The
//// club id is REQUIRED -- an archive names an existing club.

import mcl_bookclub_gleam/host_bookclub/archive_bookclub/archive_bookclub_v1
import mcl_bookclub_gleam/host_bookclub/archive_bookclub/maybe_archive_bookclub
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/payload.{type Payload}

/// Params arrive atom-keyed (the facade JSON-decodes with atom labels).
/// Both fields are REQUIRED: an archive names an existing club and who
/// did the archiving.
pub fn handle(params: Payload) -> desk.DispatchResult {
  case archive_bookclub_v1.new(params) {
    Ok(command) -> maybe_archive_bookclub.dispatch(command)
    Error(e) -> Error(e)
  }
}
