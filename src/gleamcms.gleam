import aarondb
import aarondb/storage/mnesia
import gleam/bool
import gleam/erlang/process
import gleam/int
import gleam/option.{Some}
import gleam/string
import gleamcms/builder/generator
import gleamcms/builder/importer
import gleamcms/builder/storage.{type MediaAsset, type StorageAdapter}
import gleamcms/config
import gleamcms/content/search.{type SearchMatch}
import gleamcms/db/post.{type Post}
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

pub fn init_db(cfg: config.Config) -> aarondb.Db {
  ffi.configure_mnesia_dir(config.data_dir(cfg))
  let assert Ok(Nil) = simplifile.create_directory_all(config.data_dir(cfg))
  let db = aarondb.new_with_adapter(Some(mnesia.adapter()))
  cms_schema.init_schema(db)
  db
}

pub fn start_server(cfg: config.Config) -> Nil {
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

  let db = init_db(cfg)
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

pub fn search_posts(db: aarondb.Db, query: String) -> List(SearchMatch) {
  search.search_published_posts(db, query)
}

pub fn build_all_sites(
  db: aarondb.Db,
  cfg: config.Config,
) -> List(generator.BuildReport) {
  generator.build_all(db, cfg)
}

pub fn save_post(db: aarondb.Db, p: Post) -> Result(Nil, List(String)) {
  post.save_post(db, p)
}

pub fn upload_media(
  adapter: StorageAdapter,
  content: BitArray,
  ext: String,
) -> Result(MediaAsset, String) {
  storage.store(adapter, content, ext)
}

fn format_errors(errors: List(String)) -> String {
  errors |> string.join("; ")
}
