import gleam/list
import gleamcms/theme.{type Theme}
import gleamcms/themes/catalog_a
import gleamcms/themes/catalog_b
import gleamcms/themes/configurable.{type ThemeConfig}

pub fn get_all() -> List(Theme) {
  get_configs()
  |> list.map(configurable.new)
}

pub fn get_configs() -> List(ThemeConfig) {
  list.append(catalog_a.get_configs(), catalog_b.get_configs())
}
