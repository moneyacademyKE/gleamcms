import gleamcms/db/post.{Published}
import gleamcms/events/changefeed.{ChangeEvent, PostCreated, PostPublished}
import gleeunit/should

pub fn changefeed_event_processing_test() {
  let p =
    post.new_post("1", "Event Post", "event-post", "Content")
    |> post.with_status(Published)

  let event1 = ChangeEvent(change_type: PostCreated, post: p, timestamp: 1000)
  let event2 = ChangeEvent(change_type: PostPublished, post: p, timestamp: 1001)

  let processed = changefeed.process_changes([event1, event2], [])
  processed |> should.equal(2)
}
