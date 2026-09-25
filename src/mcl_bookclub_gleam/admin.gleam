//// mcl-bookclub-gleam-admin: the LAN-facing admin UI and its JSON API.
////
//// The task-based UI the operator uses to run the club. It lives in the
//// FACADE, like /health: the facade owns the wire (cowboy, JSON), the
//// desks own the work. Every write goes through the desk's `{command}_api'
//// entry point -- the same dispatch the mesh and the tests use, so the UI
//// can never do anything the domain does not already allow.
////
//// The listener binds the box's LAN interfaces by default (0.0.0.0): the
//// UI is LAN-facing, NOT mesh-facing, on MCL_ADMIN_PORT (default 8488).
//// It is an operator tool on the same box the service runs on -- no auth
//// layer of its own, deliberately, and documented as such.

import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/erlang/charlist
import gleam/erlang/process
import gleam/list
import gleam/option.{type Option}
import mcl_bookclub_gleam/host_bookclub/archive_bookclub/archive_bookclub_api
import mcl_bookclub_gleam/host_bookclub/finish_reading/finish_reading_api
import mcl_bookclub_gleam/host_bookclub/initiate_bookclub/initiate_bookclub_api
import mcl_bookclub_gleam/host_bookclub/plan_party/plan_party_api
import mcl_bookclub_gleam/host_bookclub/procure_book/procure_book_api
import mcl_bookclub_gleam/host_bookclub/register_member/register_member_api
import mcl_bookclub_gleam/host_bookclub/retire_book/retire_book_api
import mcl_bookclub_gleam/host_bookclub/start_reading/start_reading_api
import mcl_bookclub_gleam/host_bookclub/unregister_member/unregister_member_api
import mcl_bookclub_gleam/internal/app_env
import mcl_bookclub_gleam/internal/cowboy
import mcl_bookclub_gleam/internal/desk
import mcl_bookclub_gleam/internal/payload.{type Payload, atom, wrap}
import mcl_bookclub_gleam/query_bookclub/get_book_by_id/get_book_by_id
import mcl_bookclub_gleam/query_bookclub/get_bookclub_by_id/get_bookclub_by_id
import mcl_bookclub_gleam/query_bookclub/get_member_by_id/get_member_by_id
import mcl_bookclub_gleam/query_bookclub/get_reading_by_id/get_reading_by_id
import mcl_bookclub_gleam/query_bookclub/get_readings_by_member/get_readings_by_member

const admin_ref = "mcl_bookclub_gleam_admin_http"

const app_name = "mcl_bookclub_gleam"

/// The admin listener, as a child of the facade supervisor. Port 0 gives
/// an ephemeral port (the integration test reads it back with
/// ranch:get_port/1).
pub fn start_listener() -> Result(process.Pid, dynamic.Dynamic) {
  let dispatch =
    cowboy.compile_routes([
      wrap(#(
        cowboy.any_host(),
        dynamic.list([
          route("/", "cowboy_static", static_file("admin/index.html")),
          route("/app.js", "cowboy_static", static_file("admin/app.js")),
          wrap(#(
            "/api/[...]",
            atom("mcl_bookclub_gleam@admin"),
            wrap(dict.new()),
          )),
        ]),
      )),
    ])
  let protocol_opts =
    dynamic.properties([
      #(
        atom("env"),
        dynamic.properties([
          #(atom("dispatch"), dispatch),
        ]),
      ),
    ])
  cowboy.start_clear(atom(admin_ref), socket_opts(), protocol_opts)
}

fn route(
  path: String,
  handler_module: String,
  opts: dynamic.Dynamic,
) -> dynamic.Dynamic {
  wrap(#(path, atom(handler_module), opts))
}

fn static_file(path: String) -> dynamic.Dynamic {
  wrap(#(atom("priv_file"), atom(app_name), path))
}

/// The cowboy dispatch table, tested directly by the admin tests.
pub fn routes() -> List(dynamic.Dynamic) {
  [
    route("/", "cowboy_static", static_file("admin/index.html")),
    route("/app.js", "cowboy_static", static_file("admin/app.js")),
    wrap(#("/api/[...]", atom("mcl_bookclub_gleam@admin"), wrap(dict.new()))),
  ]
}

///====================================================================
/// cowboy: single-shot, like mcl_om's own health handler -- read,
/// dispatch, reply, done, the whole request in init/2.
///====================================================================
pub fn init(req0: dynamic.Dynamic, state: dynamic.Dynamic) -> dynamic.Dynamic {
  let method = cowboy.method(req0)
  let path = cowboy.path_info(req0)
  let #(params, req1) = read_params(method, req0)
  let #(status, body) = dispatch(method, path, params)
  let req =
    cowboy.reply(status, cowboy.json_headers(), cowboy.encode(body), req1)
  wrap(#(atom("ok"), req, state))
}

fn read_params(
  method: String,
  req: dynamic.Dynamic,
) -> #(Payload, dynamic.Dynamic) {
  case method {
    "POST" ->
      case cowboy.read_body(req) {
        Ok(#(body, req1)) -> #(decode(body), req1)
        Error(_) -> #(dict.new(), req)
      }
    _ -> #(dict.new(), req)
  }
}

fn decode(body: String) -> Payload {
  case desk.decode_map(cowboy.decode_atoms(body)) {
    Ok(params) -> params
    Error(_) -> dict.new()
  }
}

///====================================================================
/// The dispatch table: one route per desk, through the desk's own entry
/// point. Public for the admin tests, which call it directly with
/// fabricated requests instead of standing up a listener.
///====================================================================
pub fn dispatch(
  method: String,
  path: List(String),
  params: Payload,
) -> #(Int, dynamic.Dynamic) {
  case method, path {
    "POST", ["clubs", "initiate"] ->
      result(initiate_bookclub_api.handle(params))
    "POST", ["clubs", "archive"] -> result(archive_bookclub_api.handle(params))
    "POST", ["clubs", "plan_party"] -> result(plan_party_api.handle(params))
    "POST", ["members", "register"] ->
      result(register_member_api.handle(enrich_club_name(params)))
    "POST", ["members", "unregister"] ->
      result(unregister_member_api.handle(params))
    "POST", ["books", "procure"] ->
      result(procure_book_api.handle(enrich_club_name(params)))
    "POST", ["books", "retire"] -> result(retire_book_api.handle(params))
    "POST", ["readings", "start"] -> result(start_reading_api.handle(params))
    "POST", ["readings", "finish"] -> result(finish_reading_api.handle(params))
    "GET", ["clubs", id] -> found(get_bookclub_by_id.find(id))
    "GET", ["members", id, "readings"] -> found(get_readings_by_member.find(id))
    "GET", ["members", id] -> found(get_member_by_id.find(id))
    "GET", ["books", id] -> found(get_book_by_id.find(id))
    "GET", ["readings", id] -> found(get_reading_by_id.find(id))
    _, _ -> #(404, wrap(dict.from_list([#(atom("error"), atom("not_found"))])))
  }
}

/// The entry point is where a command payload MAY consult the read model
/// (the corpus's one sanctioned place): the operator names a club by id,
/// and the facade stamps the club's NAME into the command so the fact a
/// downstream consumer receives is self-contained -- a thousand clubs on
/// one topic, each fact saying which club it belongs to.
fn enrich_club_name(params: Payload) -> Payload {
  case desk.get_string(params, "club_name") {
    Ok(_) -> params
    Error(_) -> enrich_from_club_id(params)
  }
}

fn enrich_from_club_id(params: Payload) -> Payload {
  case desk.get_string(params, "club_id") {
    Ok(club_id) -> stamp_club_name(params, club_id)
    Error(_) -> params
  }
}

fn stamp_club_name(params: Payload, club_id: String) -> Payload {
  case get_bookclub_by_id.find(club_id) {
    Ok(club) ->
      dict.insert(
        params,
        atom("club_name"),
        dynamic.string(desk.get_string_default(club, "name", "")),
      )
    Error(_) -> params
  }
}

fn result(dispatch_result: desk.DispatchResult) -> #(Int, dynamic.Dynamic) {
  case dispatch_result {
    Ok(#(version, events)) -> #(
      200,
      wrap(
        dict.from_list([
          #(atom("ok"), dynamic.bool(True)),
          #(atom("version"), dynamic.int(version)),
          #(
            atom("events"),
            dynamic.list(list.map(events, desk.payload_to_dynamic)),
          ),
        ]),
      ),
    )
    Error(reason) -> #(
      400,
      wrap(
        dict.from_list([
          #(atom("ok"), dynamic.bool(False)),
          #(atom("error"), reason),
        ]),
      ),
    )
  }
}

fn found(find_result: Result(a, dynamic.Dynamic)) -> #(Int, dynamic.Dynamic) {
  case find_result {
    Ok(value) -> #(200, wrap(value))
    Error(reason) -> #(
      404,
      wrap(
        dict.from_list([
          #(atom("ok"), dynamic.bool(False)),
          #(atom("error"), reason),
        ]),
      ),
    )
  }
}

///====================================================================
/// The wire's edges
///====================================================================
fn admin_port() -> Int {
  case app_env.get_env(atom(app_name), atom("admin_port"), dynamic.int(8488)) {
    port ->
      case decode.run(port, decode.int) {
        Ok(int) -> int
        Error(_) -> 8488
      }
  }
}

fn admin_ip() -> Option(String) {
  case app_env.get_env(atom(app_name), atom("admin_ip"), atom("undefined")) {
    ip ->
      case decode.run(ip, decode.string) {
        Ok(string) -> option.Some(string)
        Error(_) -> option.None
      }
  }
}

fn socket_opts() -> List(dynamic.Dynamic) {
  case admin_ip() {
    option.None -> [wrap(#(atom("port"), dynamic.int(admin_port())))]
    option.Some(ip) -> {
      let address = app_env.parse_address(wrap(charlist.from_string(ip)))
      [
        wrap(#(atom("port"), dynamic.int(admin_port()))),
        wrap(#(atom("ip"), address)),
      ]
    }
  }
}
