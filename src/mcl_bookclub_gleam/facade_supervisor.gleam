//// The facade's own supervisor: the LAN admin listener and the three
//// mesh emitters. Every other process lives in a division's tree, and
//// mcl_om owns the mesh-side processes.
////
//// The emitters live HERE, not in host_bookclub, because the facade owns
//// everything that touches the mesh (the division apps never import the
//// mesh SDK). They start after mcl_om:boot/1's catch-up replay has run,
//// which is harmless for skip-policy handlers -- replayed history is
//// skipped anyway, and live events only ever reach a registered handler.

import gleam/erlang/process
import gleam/otp/actor
import gleam/otp/static_supervisor
import gleam/otp/supervision
import gleam/string
import mcl_bookclub_gleam/admin
import mcl_bookclub_gleam/internal/evoq
import mcl_bookclub_gleam/internal/payload.{atom, new}

pub fn start() -> Result(
  actor.Started(static_supervisor.Supervisor),
  actor.StartError,
) {
  static_supervisor.new(static_supervisor.OneForOne)
  |> static_supervisor.restart_tolerance(5, 10)
  |> static_supervisor.add(supervision.worker(admin_listener_start))
  |> static_supervisor.add(handler(
    "mcl_bookclub_gleam@emit_member_registered_v1_to_mesh",
  ))
  |> static_supervisor.add(handler(
    "mcl_bookclub_gleam@emit_book_procured_v1_to_mesh",
  ))
  |> static_supervisor.add(handler(
    "mcl_bookclub_gleam@emit_book_retired_v1_to_mesh",
  ))
  |> static_supervisor.start
}

fn handler(module_name: String) -> supervision.ChildSpecification(Nil) {
  supervision.worker(fn() { evoq.handler_start(atom(module_name), new()) })
}

/// The cowboy listener as a supervisor child: the pid from start_clear,
/// an honest StartError on refusal.
fn admin_listener_start() -> Result(actor.Started(Nil), actor.StartError) {
  case admin.start_listener() {
    Ok(pid) -> Ok(actor.Started(pid: pid, data: Nil))
    Error(reason) -> Error(actor.InitFailed(string.inspect(reason)))
  }
}

/// The admin listener's pid is a process pid -- exported for tests that
/// read the port back.
pub fn admin_pid(
  started: actor.Started(static_supervisor.Supervisor),
) -> process.Pid {
  started.pid
}
