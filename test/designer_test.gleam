import gleamcms/ai/designer.{SectionDescriptor, ThemeConfig}
import gleeunit/should

pub fn sanitize_theme_config_whitelists_colors_and_css_test() {
  let unsafe_config =
    ThemeConfig(
      name: "  Hacker Theme  ",
      bg_color: "invalid-color; display:none",
      text_color: "#ffffff",
      accent_color: "rgb(0, 255, 0)",
      border_color: "#333333",
      card_bg: "url(http://evil.com)",
      font_family: "Comic Sans MS",
      layout_style: "evil style!;",
      shadow_depth: "subtle",
      border_radius: "soft",
      spacing_scale: "standard",
      custom_flourish: "@import url('http://evil.com/style.css'); .test { color: red; }",
      sections: [
        SectionDescriptor(
          title: " Hero ",
          content: "Welcome",
          section_type: "invalid_type",
        ),
      ],
    )

  let safe_config = designer.sanitize_theme_config(unsafe_config)

  safe_config.name |> should.equal("Hacker Theme")
  safe_config.bg_color |> should.equal("#0f172a")
  safe_config.text_color |> should.equal("#ffffff")
  safe_config.accent_color |> should.equal("rgb(0, 255, 0)")
  safe_config.card_bg |> should.equal("#1e293b99")
  safe_config.font_family |> should.equal("Inter")
  safe_config.layout_style |> should.equal("standard")
  safe_config.custom_flourish |> should.equal("")

  let assert [sec] = safe_config.sections
  sec.title |> should.equal("Hero")
  sec.section_type |> should.equal("content")
}
