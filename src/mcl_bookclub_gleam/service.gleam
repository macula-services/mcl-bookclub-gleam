//// The mcl_om service contract, in Gleam: the SAME org, topics and
//// procedure names as the Erlang and Phoenix bookclubs -- a drop-in third
//// club on the mesh, distinguishable only by node identity. The contract
//// is shared; the club is a payload parameter (club_id and club_name in
//// every fact).
////
//// The module also exports the two optional callbacks that turn the
//// reckon-db store on: store_id/0 and data_dir/0. mcl_om:boot/1 resolves
//// these callbacks BY NAME at startup, on a live node.

import gleam/dict
import gleam/dynamic
import mcl_bookclub_gleam/facade_supervisor
import mcl_bookclub_gleam/internal/data_dir
import mcl_bookclub_gleam/internal/health
import mcl_bookclub_gleam/internal/payload.{type Payload, atom, wrap}
import mcl_bookclub_gleam/project_bookclub/bookclub_read_model_store
import mcl_bookclub_gleam/query_bookclub/bookclub_query_store

pub fn info() -> Payload {
  dict.from_list([
    #(atom("name"), dynamic.string("mcl-bookclub")),
    #(atom("version"), dynamic.string("0.1.0")),
    #(
      atom("description"),
      dynamic.string("A book club kept as a reckon-db event store, in Gleam."),
    ),
  ])
}

/// mcl_om calls start/1 AFTER it has opened the store and started the
/// evoq subscription, so the replay has already run. The facade's own
/// supervisor (admin listener + emitters) starts here; the division
/// supervisors started earlier, in the application start callback -- see
/// app.gleam and README.md for the boot-order note.
pub fn start(_opts: Payload) -> Result(dynamic.Dynamic, dynamic.Dynamic) {
  case facade_supervisor.start() {
    Ok(started) -> Ok(wrap(started.pid))
    Error(error) -> Error(wrap(#(atom("start_failed"), wrap(error))))
  }
}

pub fn stop(_state: dynamic.Dynamic) -> dynamic.Dynamic {
  atom("ok")
}

/// The service's health IS the health of its read path: the two sqlite
/// store processes the divisions run. Their absence or silence means the
/// club's record is unreachable, however healthy the rest of the node
/// looks. gleam_otp actors are not gen_servers, so the twins'
/// try gen_server:call(Name, ping, 1000) becomes the FFI's safe_ping/2 --
/// whereis, monitor, ask, and an honest answer either way.
pub fn health() -> dynamic.Dynamic {
  case
    health.safe_ping(bookclub_read_model_store.name(), 1000),
    health.safe_ping(bookclub_query_store.name(), 1000)
  {
    Ok(_), Ok(_) -> atom("ok")
    read_model, query ->
      wrap(#(
        atom("degraded"),
        dict.from_list([
          #(atom("read_model_store"), ping_term(read_model)),
          #(atom("query_store"), ping_term(query)),
        ]),
      ))
  }
}

fn ping_term(
  result: Result(dynamic.Dynamic, dynamic.Dynamic),
) -> dynamic.Dynamic {
  case result {
    Ok(reply) -> reply
    Error(reason) -> reason
  }
}

/// WHAT THIS SERVICE ANNOUNCES IT CAN DO. Each entry is a promise that
/// something answers: get_bookclub_by_id is the mesh procedure, wired to
/// the QRY desk through the facade's get_bookclub_by_id handler -- the
/// SAME procedure name the twins advertise, so a peer cannot tell the
/// three apart.
pub fn capabilities() -> List(Payload) {
  [
    dict.from_list([
      #(atom("name"), dynamic.string("get_bookclub_by_id")),
      #(atom("version"), dynamic.int(1)),
      #(
        atom("handler"),
        wrap(#(atom("mcl_bookclub_gleam@get_bookclub_by_id"), dynamic.list([]))),
      ),
      #(atom("auth"), atom("open")),
    ]),
  ]
}

/// THE AUTHORITY THIS SERVICE ASKS THE REALM FOR, and deliberately
/// nothing more: the one procedure it serves and the three fact topics
/// its emitters publish. Popped, an attacker gains precisely this and no
/// more, which is the whole point of listing it.
pub fn identity_spec() -> Payload {
  dict.from_list([
    #(atom("scope"), dynamic.string("mcl-bookclub")),
    #(atom("actions"), dynamic.list([dynamic.string("get_bookclub_by_id")])),
    #(
      atom("resources"),
      dynamic.list([
        dynamic.string("bookclub/member/member_registered_v1"),
        dynamic.string("bookclub/book/book_procured_v1"),
        dynamic.string("bookclub/book/book_retired_v1"),
      ]),
    ),
    #(atom("ttl_days"), dynamic.int(30)),
  ])
}

/// The reckon-db store this service owns. IT IS NAMED IN TWO PLACES, here
/// and in the `evoq' block of config/sys.config.src, and nothing makes
/// them agree by itself. A test compares the two (plus the desks' dispatch
/// opts).
pub fn store_id() -> dynamic.Dynamic {
  atom("mcl_bookclub_store")
}

/// Where the record lives on disk: the reckon-db store at
/// <data_dir>/mcl_bookclub_store and the sqlite read model at
/// <data_dir>/bookclub.sqlite3. The path is a CHARLIST, not a binary: the
/// dets/ra layer under reckon-db rejects a binary file option with
/// {badarg, ...}.
pub fn data_dir() -> dynamic.Dynamic {
  data_dir.data_dir_charlist()
}
