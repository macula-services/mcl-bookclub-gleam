//// Supervises the PRJ division: the sqlite read-model store and one
//// evoq_event_handler child per projection desk.
////
//// The projection registers itself with evoq's event-type registry when
//// it starts; delivery comes from the store subscription the facade
//// boots, so this supervisor never touches the store or the adapter.

import gleam/otp/actor
import gleam/otp/static_supervisor
import gleam/otp/supervision
import mcl_bookclub_gleam/internal/data_dir
import mcl_bookclub_gleam/internal/evoq
import mcl_bookclub_gleam/internal/payload.{atom, new}
import mcl_bookclub_gleam/project_bookclub/bookclub_read_model_store

pub fn start() -> Result(
  actor.Started(static_supervisor.Supervisor),
  actor.StartError,
) {
  static_supervisor.new(static_supervisor.OneForOne)
  |> static_supervisor.restart_tolerance(5, 10)
  // The store FIRST: a projection child crashing is restarted against a
  // store that exists.
  |> static_supervisor.add(
    supervision.worker(fn() {
      bookclub_read_model_store.start(data_dir.sqlite_path())
    }),
  )
  |> static_supervisor.add(handler(
    "mcl_bookclub_gleam@project_bookclub@bookclub_initiated@bookclub_initiated_v1_to_sqlite_clubs",
  ))
  |> static_supervisor.add(handler(
    "mcl_bookclub_gleam@project_bookclub@bookclub_archived@bookclub_archived_v1_to_sqlite_clubs",
  ))
  |> static_supervisor.add(handler(
    "mcl_bookclub_gleam@project_bookclub@member_registered@member_registered_v1_to_sqlite_members",
  ))
  |> static_supervisor.add(handler(
    "mcl_bookclub_gleam@project_bookclub@member_unregistered@member_unregistered_v1_to_sqlite_members",
  ))
  |> static_supervisor.add(handler(
    "mcl_bookclub_gleam@project_bookclub@book_procured@book_procured_v1_to_sqlite_books",
  ))
  |> static_supervisor.add(handler(
    "mcl_bookclub_gleam@project_bookclub@book_retired@book_retired_v1_to_sqlite_books",
  ))
  |> static_supervisor.add(handler(
    "mcl_bookclub_gleam@project_bookclub@reading_started@reading_started_v1_to_sqlite_readings",
  ))
  |> static_supervisor.add(handler(
    "mcl_bookclub_gleam@project_bookclub@reading_finished@reading_finished_v1_to_sqlite_readings",
  ))
  |> static_supervisor.start
}

fn handler(module_name: String) -> supervision.ChildSpecification(Nil) {
  supervision.worker(fn() { evoq.handler_start(atom(module_name), new()) })
}
