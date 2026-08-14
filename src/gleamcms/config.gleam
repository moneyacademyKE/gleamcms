import gleam/int
import gleam/result
import gleam/string
import gleamcms/runtime/ffi

/// Runtime configuration loaded once at boot and threaded through the app.
pub type Config {
  Config(
    secret: String,
    admin_token: String,
    output_dir: String,
    data_dir: String,
    port: Int,
    cookie_max_age: Int,
    import_legacy: Bool,
  )
}

/// Load and validate all runtime settings from the process environment.
/// Secrets are never included in the returned errors or startup diagnostics.
pub fn load() -> Result(Config, List(String)) {
  load_with(env)
}

/// Load configuration from a supplied environment reader. Keeping validation
/// separate from the process environment makes the contract deterministic to
/// test without mutating global process state.
pub fn load_with(
  read_env: fn(String) -> Result(String, Nil),
) -> Result(Config, List(String)) {
  let secret = read_env("GLEAMCMS_SECRET") |> result.unwrap("")
  let admin_token = read_env("GLEAMCMS_ADMIN_TOKEN") |> result.unwrap("")
  let output_dir =
    read_env("GLEAMCMS_OUTPUT_DIR") |> result.unwrap("gleamcms_output")
  let data_dir =
    read_env("GLEAMCMS_DATA_DIR") |> result.unwrap("Mnesia.nonode@nohost")
  let import_legacy_raw =
    read_env("GLEAMCMS_IMPORT_LEGACY") |> result.unwrap("false")
  let import_legacy = string.lowercase(string.trim(import_legacy_raw)) == "true"
  let port_result = read_port(read_env)
  let cookie_max_age_result = read_cookie_max_age(read_env)

  let errors = []
  let errors = case is_blank(secret) {
    True -> [
      "GLEAMCMS_SECRET is required. Generate one with: openssl rand -hex 32",
      ..errors
    ]
    False -> errors
  }
  let errors = case is_blank(admin_token) {
    True -> [
      "GLEAMCMS_ADMIN_TOKEN is required. Generate one with: openssl rand -hex 16",
      ..errors
    ]
    False -> errors
  }
  let errors = case is_blank(output_dir) {
    True -> ["GLEAMCMS_OUTPUT_DIR cannot be empty", ..errors]
    False -> errors
  }
  let errors = case is_blank(data_dir) {
    True -> ["GLEAMCMS_DATA_DIR cannot be empty", ..errors]
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
      Ok(Config(
        secret,
        admin_token,
        output_dir,
        data_dir,
        port,
        cookie_max_age,
        import_legacy,
      ))
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

pub fn data_dir(cfg: Config) -> String {
  cfg.data_dir
}

pub fn import_legacy(cfg: Config) -> Bool {
  cfg.import_legacy
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

fn read_port(
  read_env: fn(String) -> Result(String, Nil),
) -> Result(Int, String) {
  case read_env("GLEAMCMS_PORT") {
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

fn read_cookie_max_age(
  read_env: fn(String) -> Result(String, Nil),
) -> Result(Int, String) {
  case read_env("GLEAMCMS_COOKIE_MAX_AGE") {
    Error(_) -> Ok(86_400)
    Ok(raw) ->
      case int.parse(raw) {
        Error(_) ->
          Error(
            "GLEAMCMS_COOKIE_MAX_AGE must be an integer between 60 and 2592000",
          )
        Ok(value) if value >= 60 && value <= 86_400 * 30 -> Ok(value)
        Ok(_) ->
          Error(
            "GLEAMCMS_COOKIE_MAX_AGE must be an integer between 60 and 2592000",
          )
      }
  }
}

fn is_blank(value: String) -> Bool {
  value |> string.trim |> string.is_empty
}

fn env(name: String) -> Result(String, Nil) {
  ffi.get_env(name)
}
