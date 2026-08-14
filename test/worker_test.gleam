import gleam/erlang/process
import gleamcms/runtime/worker
import gleeunit/should

pub fn async_worker_task_execution_test() {
  let caller = process.new_subject()

  worker.spawn_task(fn() { process.send(caller, "task_done") })

  let msg = process.receive(caller, 2000)
  msg |> should.equal(Ok("task_done"))
}
