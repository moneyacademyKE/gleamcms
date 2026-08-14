import gleam/result
import gleamcms/builder/storage.{type StorageAdapter}

pub type AssetHash =
  String

pub fn store_asset(
  content: BitArray,
  extension: String,
) -> Result(AssetHash, String) {
  let adapter = storage.default_local_adapter()
  storage.store(adapter, content, extension)
  |> result.map(fn(asset) { asset.hash })
}

pub fn store_asset_with_adapter(
  adapter: StorageAdapter,
  content: BitArray,
  extension: String,
) -> Result(storage.MediaAsset, String) {
  storage.store(adapter, content, extension)
}

pub fn get_public_url(hash: AssetHash, extension: String) -> String {
  storage.resolve_url(storage.default_local_adapter(), hash, extension)
}
