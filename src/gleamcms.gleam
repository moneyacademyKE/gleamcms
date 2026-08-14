import aarondb
import aarondb/storage/mnesia
import gleam/bool
import gleam/erlang/process
import gleam/int
import gleam/option.{Some}
import gleam/string
import gleamcms/builder/importer
import gleamcms/config
import gleamcms/db/schema as cms_schema
import gleamcms/runtime/ffi
import gleamcms/server/router as cms_router
import logging
import mist
import simplifile
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
      <> "; data directory: "
      <> config.data_dir(cfg)
      <> "; admin: "
      <> bool.to_string(config.admin_enabled(cfg)),
  )

  ffi.configure_mnesia_dir(config.data_dir(cfg))
  let assert Ok(Nil) = simplifile.create_directory_all(config.data_dir(cfg))
  let db = aarondb.new_with_adapter(Some(mnesia.adapter()))
  cms_schema.init_schema(db)
  case config.import_legacy(cfg) {
    True -> {
      case importer.run_import(db, "legacy_posts.json") {
        Ok(count) ->
          logging.log(
            logging.Info,
            "Imported " <> int.to_string(count) <> " legacy posts",
          )
        Error(message) ->
          logging.log(logging.Error, "Legacy import failed: " <> message)
      }
    }
    False -> Nil
  }

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
