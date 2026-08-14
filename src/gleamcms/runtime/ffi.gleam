//// Runtime FFI bindings to Erlang modules.
//// Isolates non-portable and host-level primitives at the runtime edge.

@external(erlang, "gleamcms_httpc_ffi", "get_env")
pub fn get_env(name: String) -> Result(String, Nil)

@external(erlang, "gleamcms_httpc_ffi", "hmac_sha256")
pub fn hmac_sha256(secret: String, msg: String) -> String

@external(erlang, "gleamcms_httpc_ffi", "configure_mnesia_dir")
pub fn configure_mnesia_dir(dir: String) -> Nil

@external(erlang, "gleamcms_httpc_ffi", "run_gemini")
pub fn run_gemini(
  system_prompt: String,
  user_prompt: String,
) -> Result(String, String)

@external(erlang, "gleamcms_httpc_ffi", "post")
pub fn post(
  url: String,
  headers: List(#(String, String)),
  body: String,
) -> Result(String, String)

@external(erlang, "gleamcms_httpc_ffi", "spawn_task")
pub fn spawn_task(task: fn() -> Nil) -> Nil
