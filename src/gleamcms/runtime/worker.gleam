import aarondb
import gleamcms/builder/generator
import gleamcms/config
import gleamcms/db/post.{type Post}
import gleamcms/events/webhook.{type WebhookSubscription, PostPublishedEvent}
import gleamcms/runtime/ffi

pub fn spawn_task(task: fn() -> Nil) -> Nil {
  ffi.spawn_task(task)
}

pub fn async_dispatch_post_published(
  subs: List(WebhookSubscription),
  post: Post,
) -> Nil {
  spawn_task(fn() {
    let event =
      PostPublishedEvent(
        id: post.get_id(post),
        slug: post.get_slug(post),
        title: post.get_title(post),
        timestamp: 1_700_000_000,
      )
    let payload = webhook.encode_post_published_event(event)
    let _ = webhook.dispatch_to_all(subs, payload)
    Nil
  })
}

pub fn async_generate_site(
  db: aarondb.Db,
  theme_name: String,
  cfg: config.Config,
) -> Nil {
  spawn_task(fn() {
    let _ = generator.build(db, theme_name, cfg)
    Nil
  })
}
