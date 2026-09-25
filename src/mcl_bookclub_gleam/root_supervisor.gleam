//// The root supervisor: the three divisions, in start order.
////
//// Started by the application start callback BEFORE mcl_om:boot/1 runs, so
//// by the time boot's evoq subscription replays, every deliver-policy
//// projection is registered and listening -- the single-app equivalent of
//// the twins' umbrella application order. The facade's own supervisor
//// starts later, inside ServiceMod:start/1 (see service.gleam).

import gleam/otp/actor
import gleam/otp/static_supervisor
import gleam/otp/supervision
import mcl_bookclub_gleam/host_bookclub_sup
import mcl_bookclub_gleam/project_bookclub_sup
import mcl_bookclub_gleam/query_bookclub_sup

pub fn start() -> Result(actor.Started(static_supervisor.Supervisor), actor.StartError) {
  static_supervisor.new(static_supervisor.OneForOne)
  |> static_supervisor.restart_tolerance(5, 10)
  |> static_supervisor.add(supervision.supervisor(project_bookclub_sup.start))
  |> static_supervisor.add(supervision.supervisor(query_bookclub_sup.start))
  |> static_supervisor.add(supervision.supervisor(host_bookclub_sup.start))
  |> static_supervisor.start
}
