//// This service's reckon-db store, opened by app.gleam BEFORE mcl_om:boot/1.
////
//// From mcl_om 0.35 on, mcl_om opens no store and brings no reckon-db or
//// evoq application (mcl-om#10): each service owns its persistence. The
//// wiring is this service's own copy of the canonical pattern, in the FFI
//// (mcl_bookclub_gleam_ffi:open_store/2): start the store, wait until
//// reckon-db lists it, start the per-store evoq subscription. NOT in the
//// service module as store_id/0 and data_dir/0: mcl_om 0.35 warns at every
//// boot about a service module exporting that pair.

import gleam/dynamic
import mcl_bookclub_gleam/internal/data_dir
import mcl_bookclub_gleam/internal/evoq

/// The store's id. Named in two more places, evoq's dispatch opts and the
/// `evoq' block of config/sys.config.src; tests pin all three together.
pub fn id() -> dynamic.Dynamic {
  evoq.store_id_atom()
}

/// Where it lives: the store at <dir>/mcl_bookclub_store, beside the sqlite
/// read model. A REAL charlist: dets/ra rejects a binary file option.
pub fn dir() -> dynamic.Dynamic {
  data_dir.data_dir_charlist()
}

/// Opens the store and its subscription, or answers why it could not.
pub fn open() -> Result(Nil, dynamic.Dynamic) {
  open_store(id(), dir())
}

@external(erlang, "mcl_bookclub_gleam_ffi", "open_store")
fn open_store(
  id: dynamic.Dynamic,
  dir: dynamic.Dynamic,
) -> Result(Nil, dynamic.Dynamic)
