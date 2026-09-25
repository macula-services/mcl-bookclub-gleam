//// The book aggregate's status: the flags, AND their readable names.
////
//// The raw flags are one power of two each; THIS module owns the flag map
//// that names them. The projections derive their status strings from
//// here -- a readable-status literal inside a projection is the Demon 68
//// relapse.

import gleam/dict
import mcl_bookclub_gleam/internal/evoq

/// 2^0: procured, on the club's shelf.
pub fn on_shelf() -> Int {
  1
}

/// 2^1: soft-deleted; commands refused.
pub fn retired() -> Int {
  2
}

/// Flag -> readable name. The values are the read-model contract's status
/// strings, pinned by the status tests.
pub fn flag_map() -> dict.Dict(Int, String) {
  dict.from_list([#(on_shelf(), "on_shelf"), #(retired(), "retired")])
}

/// A mask, rendered readable through evoq's own flag-map conversion.
pub fn to_string(status: Int) -> String {
  evoq.bit_to_string(status, flag_map())
}
