import aarondb
import gleam/bool
import gleam/erlang/process
import gleam/int
import gleam/string
import gleamcms/builder/importer
import gleamcms/config
import gleamcms/db/schema as cms_schema
import gleamcms/server/router as cms_router
import logging
import mist
import wisp/wisp_mist

pub fn main() {
  logging.configure()
  case config.load() {
    Ok(cfg) -> start_server(cfg)
    Error(errors) -> {
      logging.log(
        logging.Error,
        "Invalid configuration: " <> format_errors(errors),
      )
      Nil
    }
  }
}

fn start_server(cfg: config.Config) {
  logging.log(
    logging.Info,
    "Starting GleamCMS on port "
      <> int.to_string(config.port(cfg))
      <> "; output directory: "
      <> config.output_dir(cfg)
      <> "; admin: "
      <> bool.to_string(config.admin_enabled(cfg)),
  )

  let db = aarondb.new()
  cms_schema.init_schema(db)
  let _ = importer.run_import(db, "legacy_posts.json")

  let assert Ok(_) =
    wisp_mist.handler(cms_router.handle_request(_, db, cfg), config.secret(cfg))
    |> mist.new()
    |> mist.port(config.port(cfg))
    |> mist.start()

  process.sleep_forever()
}

fn format_errors(errors: List(String)) -> String {
  errors |> string.join("; ")
}
