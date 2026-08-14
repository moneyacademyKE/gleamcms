import gleam/bit_array
import gleam/crypto
import gleam/list
import gleam/string
import simplifile

pub type StorageAdapter {
  LocalStorage(base_path: String, url_prefix: String)
  S3Storage(
    bucket: String,
    region: String,
    endpoint: String,
    access_key: String,
    secret_key: String,
  )
}

pub type MediaAsset {
  MediaAsset(
    hash: String,
    mime_type: String,
    extension: String,
    size_bytes: Int,
    public_url: String,
  )
}

pub fn default_local_adapter() -> StorageAdapter {
  LocalStorage(base_path: "priv/static/media", url_prefix: "/static/media")
}

pub fn verify_extension(raw_extension: String) -> Result(String, String) {
  let clean =
    raw_extension
    |> string.trim
    |> string.lowercase
    |> string.replace(".", "")

  let allowed = [
    "jpg", "jpeg", "png", "webp", "gif", "svg", "mp4", "webm", "mp3", "pdf",
    "txt", "json",
  ]

  case list.contains(allowed, clean) {
    True -> Ok(clean)
    False ->
      Error(
        "Disallowed file extension: "
        <> clean
        <> ". Supported: images, video, audio, pdf.",
      )
  }
}

pub fn mime_for_extension(extension: String) -> String {
  case extension {
    "jpg" | "jpeg" -> "image/jpeg"
    "png" -> "image/png"
    "webp" -> "image/webp"
    "gif" -> "image/gif"
    "svg" -> "image/svg+xml"
    "mp4" -> "video/mp4"
    "webm" -> "video/webm"
    "mp3" -> "audio/mpeg"
    "pdf" -> "application/pdf"
    "json" -> "application/json"
    _ -> "application/octet-stream"
  }
}

pub fn store(
  adapter: StorageAdapter,
  content: BitArray,
  raw_extension: String,
) -> Result(MediaAsset, String) {
  use clean_ext <- result_try(verify_extension(raw_extension))
  let hash =
    crypto.hash(crypto.Sha256, content)
    |> bit_array.base16_encode
    |> string.lowercase
  let size = bit_array.byte_size(content)
  let mime = mime_for_extension(clean_ext)

  case adapter {
    LocalStorage(base_path, url_prefix) -> {
      let _ = simplifile.create_directory_all(base_path)
      let filename = hash <> "." <> clean_ext
      let path = base_path <> "/" <> filename
      let url = url_prefix <> "/" <> filename

      case simplifile.is_file(path) {
        Ok(True) ->
          Ok(MediaAsset(
            hash: hash,
            mime_type: mime,
            extension: clean_ext,
            size_bytes: size,
            public_url: url,
          ))
        _ -> {
          case simplifile.write_bits(path, content) {
            Ok(_) ->
              Ok(MediaAsset(
                hash: hash,
                mime_type: mime,
                extension: clean_ext,
                size_bytes: size,
                public_url: url,
              ))
            Error(e) -> Error(simplifile.describe_error(e))
          }
        }
      }
    }
    S3Storage(bucket, region, endpoint, _, _) -> {
      let filename = hash <> "." <> clean_ext
      let url = case endpoint {
        "" ->
          "https://"
          <> bucket
          <> ".s3."
          <> region
          <> ".amazonaws.com/"
          <> filename
        ep -> ep <> "/" <> bucket <> "/" <> filename
      }
      Ok(MediaAsset(
        hash: hash,
        mime_type: mime,
        extension: clean_ext,
        size_bytes: size,
        public_url: url,
      ))
    }
  }
}

pub fn resolve_url(
  adapter: StorageAdapter,
  hash: String,
  extension: String,
) -> String {
  let clean_ext = string.replace(extension, ".", "")
  let filename = hash <> "." <> clean_ext
  case adapter {
    LocalStorage(_, url_prefix) -> url_prefix <> "/" <> filename
    S3Storage(bucket, region, endpoint, _, _) ->
      case endpoint {
        "" ->
          "https://"
          <> bucket
          <> ".s3."
          <> region
          <> ".amazonaws.com/"
          <> filename
        ep -> ep <> "/" <> bucket <> "/" <> filename
      }
  }
}

fn result_try(res: Result(a, e), f: fn(a) -> Result(b, e)) -> Result(b, e) {
  case res {
    Ok(val) -> f(val)
    Error(err) -> Error(err)
  }
}
