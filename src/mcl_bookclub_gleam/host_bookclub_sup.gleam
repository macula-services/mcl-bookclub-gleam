//// Supervises the CMD division's own processes.
////
//// Aggregates are started on demand by evoq's own partition supervisors
//// when a command targets them -- they never appear in a service
//// supervisor. What lives here are the things that subscribe to events:
//// the policy slice (on_member_registered_v1_maybe_plan_party), one
//// evoq_event_handler child.

import gleam/otp/actor
import gleam/otp/static_supervisor
import gleam/otp/supervision
import mcl_bookclub_gleam/internal/evoq
import mcl_bookclub_gleam/internal/payload.{atom, new}

const party_policy_module =
  "mcl_bookclub_gleam@host_bookclub@on_member_registered_v1_maybe_plan_party"

pub fn start() -> Result(actor.Started(static_supervisor.Supervisor), actor.StartError) {
  static_supervisor.new(static_supervisor.OneForOne)
  |> static_supervisor.restart_tolerance(5, 10)
  |> static_supervisor.add(supervision.worker(fn() {
    evoq.handler_start(atom(party_policy_module), new())
  }))
  |> static_supervisor.start
}
