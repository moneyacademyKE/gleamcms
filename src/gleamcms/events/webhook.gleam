import gleam/json
import gleam/list
import gleamcms/runtime/ffi

pub type WebhookSubscription {
  WebhookSubscription(id: String, url: String, secret: String, active: Bool)
}

pub type PostPublishedEvent {
  PostPublishedEvent(id: String, slug: String, title: String, timestamp: Int)
}

pub fn sign_payload(payload: String, secret: String) -> String {
  ffi.hmac_sha256(secret, payload)
}

pub fn encode_post_published_event(event: PostPublishedEvent) -> String {
  json.object([
    #("event", json.string("post.published")),
    #(
      "data",
      json.object([
        #("id", json.string(event.id)),
        #("slug", json.string(event.slug)),
        #("title", json.string(event.title)),
        #("timestamp", json.int(event.timestamp)),
      ]),
    ),
  ])
  |> json.to_string
}

pub fn dispatch_event(
  url: String,
  secret: String,
  payload: String,
) -> Result(String, String) {
  let signature = sign_payload(payload, secret)
  let headers = [
    #("content-type", "application/json"),
    #("x-gleamcms-signature-256", signature),
    #("user-agent", "GleamCMS-Webhook-Dispatcher/1.0"),
  ]
  ffi.post(url, headers, payload)
}

pub fn dispatch_to_all(
  subscriptions: List(WebhookSubscription),
  payload: String,
) -> List(Result(String, String)) {
  subscriptions
  |> list.filter(fn(sub) { sub.active })
  |> list.map(fn(sub) { dispatch_event(sub.url, sub.secret, payload) })
}
