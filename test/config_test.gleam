import gleam/dict
import gleamcms/config
import gleeunit/should

fn env(values: List(#(String, String))) -> fn(String) -> Result(String, Nil) {
  fn(name) {
    case dict.get(dict.from_list(values), name) {
      Ok(value) -> Ok(value)
      Error(_) -> Error(Nil)
    }
  }
}

pub fn missing_secrets_fail_closed_test() {
  config.load_with(env([]))
  |> should.be_error
}

pub fn missing_admin_credentials_fail_closed_test() {
  let values = [#("GLEAMCMS_SECRET", "test-secret")]

  config.load_with(env(values))
  |> should.be_error
}

pub fn invalid_port_is_rejected_test() {
  let values = [
    #("GLEAMCMS_SECRET", "test-secret"),
    #("GLEAMCMS_ADMIN_TOKEN", "test-token"),
    #("GLEAMCMS_PORT", "70000"),
  ]

  config.load_with(env(values))
  |> should.be_error
}

pub fn invalid_cookie_max_age_is_rejected_test() {
  let values = [
    #("GLEAMCMS_SECRET", "test-secret"),
    #("GLEAMCMS_ADMIN_TOKEN", "test-token"),
    #("GLEAMCMS_COOKIE_MAX_AGE", "30"),
  ]

  config.load_with(env(values))
  |> should.be_error
}

pub fn blank_output_directory_is_rejected_test() {
  let values = [
    #("GLEAMCMS_SECRET", "test-secret"),
    #("GLEAMCMS_ADMIN_TOKEN", "test-token"),
    #("GLEAMCMS_OUTPUT_DIR", "  "),
  ]

  config.load_with(env(values))
  |> should.be_error
}

pub fn valid_defaults_are_applied_without_exposing_secrets_test() {
  let values = [
    #("GLEAMCMS_SECRET", "test-secret"),
    #("GLEAMCMS_ADMIN_TOKEN", "test-token"),
  ]

  let assert Ok(cfg) = config.load_with(env(values))
  config.port(cfg) |> should.equal(4000)
  config.cookie_max_age(cfg) |> should.equal(86_400)
  config.output_dir(cfg) |> should.equal("gleamcms_output")
  config.admin_enabled(cfg) |> should.be_true
}

pub fn custom_runtime_values_are_applied_test() {
  let values = [
    #("GLEAMCMS_SECRET", "test-secret"),
    #("GLEAMCMS_ADMIN_TOKEN", "test-token"),
    #("GLEAMCMS_OUTPUT_DIR", "/var/lib/gleamcms/sites"),
    #("GLEAMCMS_PORT", "8080"),
    #("GLEAMCMS_COOKIE_MAX_AGE", "3600"),
  ]

  let assert Ok(cfg) = config.load_with(env(values))
  config.output_dir(cfg) |> should.equal("/var/lib/gleamcms/sites")
  config.port(cfg) |> should.equal(8080)
  config.cookie_max_age(cfg) |> should.equal(3600)
}
