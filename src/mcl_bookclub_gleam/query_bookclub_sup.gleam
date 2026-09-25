//// Supervises the QRY division: the sqlite query store.
////
//// One child today. Every later query desk is a pure module answered by
//// the store, not a process -- the desks hold no state of their own.

import gleam/otp/actor
import gleam/otp/static_supervisor
import gleam/otp/supervision
import mcl_bookclub_gleam/internal/data_dir
import mcl_bookclub_gleam/query_bookclub/bookclub_query_store

pub fn start() -> Result(actor.Started(static_supervisor.Supervisor), actor.StartError) {
  static_supervisor.new(static_supervisor.OneForOne)
  |> static_supervisor.restart_tolerance(5, 10)
  |> static_supervisor.add(supervision.worker(fn() {
    bookclub_query_store.start(data_dir.sqlite_path())
  }))
  |> static_supervisor.start
}
