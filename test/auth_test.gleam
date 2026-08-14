import gleam/http
import gleam/list
import gleamcms/config
import gleamcms/server/auth
import gleeunit/should
import wisp
import wisp/simulate

pub fn session_value_is_deterministic_test() {
  let v1 = auth.session_value("secret-123")
  let v2 = auth.session_value("secret-123")
  let v3 = auth.session_value("different-secret")

  v1 |> should.equal(v2)
  { v1 != v3 } |> should.be_true
}

pub fn set_session_cookie_adds_cookie_header_test() {
  let cfg =
    config.Config(
      secret: "test-secret",
      admin_token: "test-token",
      output_dir: "output",
      data_dir: "data",
      port: 4000,
      cookie_max_age: 3600,
      import_legacy: False,
    )
  let resp = wisp.ok() |> auth.set_session_cookie("test-secret", cfg)
  let cookie = list.key_find(resp.headers, "set-cookie")

  cookie |> should.be_ok
}

pub fn get_login_renders_form_without_authenticating_query_param_test() {
  let cfg =
    config.Config(
      secret: "test-secret",
      admin_token: "test-token",
      output_dir: "output",
      data_dir: "data",
      port: 4000,
      cookie_max_age: 3600,
      import_legacy: False,
    )
  let req = simulate.request(http.Get, "/admin/login?token=test-token")
  let resp = auth.handle_login(req, cfg)

  resp.status |> should.equal(200)
  list.key_find(resp.headers, "set-cookie") |> should.be_error
}

pub fn post_login_authenticates_valid_token_test() {
  let cfg =
    config.Config(
      secret: "test-secret",
      admin_token: "test-token",
      output_dir: "output",
      data_dir: "data",
      port: 4000,
      cookie_max_age: 3600,
      import_legacy: False,
    )
  let req =
    simulate.request(http.Post, "/admin/login")
    |> simulate.string_body("token=test-token")
  let resp = auth.handle_login(req, cfg)

  resp.status |> should.equal(303)
  let cookie = list.key_find(resp.headers, "set-cookie")
  cookie |> should.be_ok
}

pub fn post_login_rejects_invalid_token_test() {
  let cfg =
    config.Config(
      secret: "test-secret",
      admin_token: "test-token",
      output_dir: "output",
      data_dir: "data",
      port: 4000,
      cookie_max_age: 3600,
      import_legacy: False,
    )
  let req =
    simulate.request(http.Post, "/admin/login")
    |> simulate.string_body("token=wrong-token")
  let resp = auth.handle_login(req, cfg)

  resp.status |> should.equal(200)
  list.key_find(resp.headers, "set-cookie") |> should.be_error
}
