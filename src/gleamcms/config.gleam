import gleam/int
import gleam/result
import gleamcms/ai/designer

/// Runtime configuration loaded once at boot and threaded through the app.
pub type Config {
  Config(
    secret: String,
    admin_token: String,
    output_dir: String,
    port: Int,
    cookie_max_age: Int,
  )
}

/// Load and validate all runtime settings. Secrets are never included in the
/// returned errors or startup diagnostics.
pub fn load() -> Result(Config, List(String)) {
  let secret = env("GLEAMCMS_SECRET") |> result.unwrap("")
  let admin_token = env("GLEAMCMS_ADMIN_TOKEN") |> result.unwrap("")
  let output_dir =
    env("GLEAMCMS_OUTPUT_DIR") |> result.unwrap("gleamcms_output")
  let port_result = read_port()
  let cookie_max_age_result = read_cookie_max_age()

  let errors = []
  let errors = case secret == "" {
    True -> [
      "GLEAMCMS_SECRET is required. Generate one with: openssl rand -hex 32",
      ..errors
    ]
    False -> errors
  }
  let errors = case admin_token == "" {
    True -> [
      "GLEAMCMS_ADMIN_TOKEN is required. Generate one with: openssl rand -hex 16",
      ..errors
    ]
    False -> errors
  }
  let errors = case output_dir == "" {
    True -> ["GLEAMCMS_OUTPUT_DIR cannot be empty", ..errors]
    False -> errors
  }
  let errors = case port_result {
    Ok(_) -> errors
    Error(message) -> [message, ..errors]
  }
  let errors = case cookie_max_age_result {
    Ok(_) -> errors
    Error(message) -> [message, ..errors]
  }

  case errors, port_result, cookie_max_age_result {
    [], Ok(port), Ok(cookie_max_age) ->
      Ok(Config(secret, admin_token, output_dir, port, cookie_max_age))
    _, _, _ -> Error(errors)
  }
}

pub fn secret(cfg: Config) -> String {
  cfg.secret
}

pub fn admin_token(cfg: Config) -> String {
  cfg.admin_token
}

pub fn output_dir(cfg: Config) -> String {
  cfg.output_dir
}

pub fn port(cfg: Config) -> Int {
  cfg.port
}

pub fn cookie_max_age(cfg: Config) -> Int {
  cfg.cookie_max_age
}

pub fn admin_enabled(cfg: Config) -> Bool {
  cfg.secret != "" && cfg.admin_token != ""
}

fn read_port() -> Result(Int, String) {
  case env("GLEAMCMS_PORT") {
    Error(_) -> Ok(4000)
    Ok(raw) ->
      case int.parse(raw) {
        Error(_) ->
          Error("GLEAMCMS_PORT must be an integer between 1 and 65535")
        Ok(value) if value > 0 && value <= 65_535 -> Ok(value)
        Ok(_) -> Error("GLEAMCMS_PORT must be an integer between 1 and 65535")
      }
  }
}

fn read_cookie_max_age() -> Result(Int, String) {
  case env("GLEAMCMS_COOKIE_MAX_AGE") {
    Error(_) -> Ok(86_400)
    Ok(raw) ->
      case int.parse(raw) {
        Error(_) ->
          Error(
            "GLEAMCMS_COOKIE_MAX_AGE must be an integer between 60 and 86400 * 30",
          )
        Ok(value) if value >= 60 && value <= 86_400 * 30 -> Ok(value)
        Ok(_) ->
          Error(
            "GLEAMCMS_COOKIE_MAX_AGE must be an integer between 60 and 2592000",
          )
      }
  }
}

fn env(name: String) -> Result(String, Nil) {
  designer.get_env(name)
}
