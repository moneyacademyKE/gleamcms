import gleam/list
import gleamcms/db/post.{type Post}
import gleamcms/events/webhook.{type WebhookSubscription}
import gleamcms/runtime/worker

pub type ChangeType {
  PostCreated
  PostUpdated
  PostPublished
  PostArchived
}

pub type ChangeEvent {
  ChangeEvent(change_type: ChangeType, post: Post, timestamp: Int)
}

/// Project a change event to subscribers asynchronously.
pub fn project_change(
  event: ChangeEvent,
  subscriptions: List(WebhookSubscription),
) -> Nil {
  case event.change_type {
    PostPublished -> {
      worker.async_dispatch_post_published(subscriptions, event.post)
    }
    _ -> Nil
  }
}

/// Batch process multiple change events.
pub fn process_changes(
  events: List(ChangeEvent),
  subscriptions: List(WebhookSubscription),
) -> Int {
  list.each(events, fn(e) { project_change(e, subscriptions) })
  list.length(events)
}
