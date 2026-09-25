//// The member aggregate's status: the flags, AND their readable names.
////
//// The raw flags are one power of two each; THIS module owns the flag map
//// that names them. The unregistered flag is the member's soft-delete.
//// The projections derive their status strings from here -- a
//// readable-status literal inside a projection is the Demon 68 relapse.

import gleam/dict
import mcl_bookclub_gleam/internal/evoq

/// 2^0: the member exists.
pub fn registered() -> Int {
  1
}

/// 2^1: soft-deleted; commands refused.
pub fn unregistered() -> Int {
  2
}

/// Flag -> readable name. The values are the read-model contract's status
/// strings, pinned by the status tests.
pub fn flag_map() -> dict.Dict(Int, String) {
  dict.from_list([#(registered(), "active"), #(unregistered(), "unregistered")])
}

/// A mask, rendered readable through evoq's own flag-map conversion.
pub fn to_string(status: Int) -> String {
  evoq.bit_to_string(status, flag_map())
}
