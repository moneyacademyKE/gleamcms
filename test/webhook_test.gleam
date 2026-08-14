import gleam/list
import gleam/string
import gleamcms/events/webhook.{PostPublishedEvent, WebhookSubscription}
import gleeunit/should

pub fn encode_and_sign_webhook_payload_test() {
  let event =
    PostPublishedEvent(
      id: "post-101",
      slug: "first-post",
      title: "First Post",
      timestamp: 1_700_000_000,
    )

  let payload = webhook.encode_post_published_event(event)
  string.contains(payload, "\"event\":\"post.published\"") |> should.be_true
  string.contains(payload, "\"slug\":\"first-post\"") |> should.be_true

  let secret = "test-webhook-secret"
  let sig1 = webhook.sign_payload(payload, secret)
  let sig2 = webhook.sign_payload(payload, secret)
  let sig3 = webhook.sign_payload(payload, "different-secret")

  sig1 |> should.equal(sig2)
  { sig1 != sig3 } |> should.be_true
}

pub fn filter_inactive_subscriptions_test() {
  let active_sub =
    WebhookSubscription(
      id: "sub-1",
      url: "https://example.com/webhook",
      secret: "sec1",
      active: True,
    )
  let inactive_sub =
    WebhookSubscription(
      id: "sub-2",
      url: "https://example.com/disabled",
      secret: "sec2",
      active: False,
    )

  let subs = [active_sub, inactive_sub]
  let results = webhook.dispatch_to_all(subs, "payload")
  list.length(results) |> should.equal(1)
}
