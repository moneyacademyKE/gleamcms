import gleam/list
import gleamcms/themes/catalog_a
import gleamcms/themes/catalog_b
import gleamcms/themes/library
import gleeunit/should

pub fn theme_catalogs_partition_correctly_test() {
  let a = catalog_a.get_configs()
  let b = catalog_b.get_configs()
  let all = library.get_configs()

  list.length(a) |> should.equal(25)
  list.length(b) |> should.equal(26)
  list.length(all) |> should.equal(51)
}

pub fn all_themes_instantiate_test() {
  let themes = library.get_all()
  list.length(themes) |> should.equal(51)
}
