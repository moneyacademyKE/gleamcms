import gleam/bit_array
import gleam/string
import gleamcms/builder/storage.{LocalStorage, S3Storage}
import gleeunit/should
import simplifile

pub fn storage_whitelists_safe_extensions_test() {
  storage.verify_extension("png") |> should.be_ok
  storage.verify_extension(".jpg") |> should.be_ok
  storage.verify_extension("webp") |> should.be_ok
  storage.verify_extension("mp4") |> should.be_ok

  storage.verify_extension("exe") |> should.be_error
  storage.verify_extension("php") |> should.be_error
  storage.verify_extension("sh") |> should.be_error
}

pub fn storage_mime_resolution_test() {
  storage.mime_for_extension("png") |> should.equal("image/png")
  storage.mime_for_extension("jpg") |> should.equal("image/jpeg")
  storage.mime_for_extension("mp4") |> should.equal("video/mp4")
  storage.mime_for_extension("pdf") |> should.equal("application/pdf")
}

pub fn storage_magic_byte_sniffing_test() {
  let png_bytes = <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00>>
  let jpeg_bytes = <<0xFF, 0xD8, 0xFF, 0xE0, 0x00>>
  let pdf_bytes = <<"%PDF-1.4", 0x0A>>
  let webp_bytes = <<
    0x52,
    0x49,
    0x46,
    0x46,
    0x00,
    0x00,
    0x00,
    0x00,
    0x57,
    0x45,
    0x42,
    0x50,
  >>

  storage.sniff_magic_mime(png_bytes) |> should.equal(Ok("image/png"))
  storage.sniff_magic_mime(jpeg_bytes) |> should.equal(Ok("image/jpeg"))
  storage.sniff_magic_mime(pdf_bytes) |> should.equal(Ok("application/pdf"))
  storage.sniff_magic_mime(webp_bytes) |> should.equal(Ok("image/webp"))
}

pub fn storage_detects_and_rejects_spoofed_extensions_test() {
  let adapter =
    LocalStorage(
      base_path: "test_media_output",
      url_prefix: "/static/test_media",
    )
  // PDF content passed with .png extension
  let pdf_content = <<"%PDF-1.4 Fake Image">>

  storage.store(adapter, pdf_content, "png") |> should.be_error
}

pub fn storage_cas_deduplication_local_test() {
  let adapter =
    LocalStorage(
      base_path: "test_media_output",
      url_prefix: "/static/test_media",
    )
  let content = <<
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    "valid image",
  >>

  let assert Ok(asset1) = storage.store(adapter, content, "png")
  let assert Ok(asset2) = storage.store(adapter, content, "png")

  asset1.hash |> should.equal(asset2.hash)
  asset1.public_url
  |> should.equal("/static/test_media/" <> asset1.hash <> ".png")
  asset1.mime_type |> should.equal("image/png")

  // Verify file exists on disk
  let file_path = "test_media_output/" <> asset1.hash <> ".png"
  simplifile.is_file(file_path) |> should.equal(Ok(True))

  // Clean up
  let _ = simplifile.delete("test_media_output")
  Nil
}

pub fn storage_s3_adapter_url_generation_test() {
  let adapter =
    S3Storage(
      bucket: "my-media-bucket",
      region: "us-east-1",
      endpoint: "",
      access_key: "key",
      secret_key: "secret",
    )
  let content = bit_array.from_string("s3 cloud text data")

  let assert Ok(asset) = storage.store(adapter, content, "txt")
  string.starts_with(
    asset.public_url,
    "https://my-media-bucket.s3.us-east-1.amazonaws.com/",
  )
  |> should.be_true
}
