pub type SectionDescriptor {
  SectionDescriptor(title: String, content: String, section_type: String)
}

pub type ThemeConfig {
  ThemeConfig(
    name: String,
    bg_color: String,
    text_color: String,
    accent_color: String,
    border_color: String,
    card_bg: String,
    font_family: String,
    layout_style: String,
    shadow_depth: String,
    border_radius: String,
    spacing_scale: String,
    custom_flourish: String,
    sections: List(SectionDescriptor),
  )
}

import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/string
import gleamcms/runtime/ffi

pub fn run_gemini(
  system_prompt: String,
  user_prompt: String,
) -> Result(String, String) {
  ffi.run_gemini(system_prompt, user_prompt)
}

pub fn get_env(name: String) -> Result(String, Nil) {
  ffi.get_env(name)
}

pub fn hmac_sha256(secret: String, msg: String) -> String {
  ffi.hmac_sha256(secret, msg)
}

pub fn design_theme(prompt: String) -> Result(ThemeConfig, String) {
  let system_instruction =
    "You are a World-Class Digital Agency Lead. Generate a premium landing page specification for GleamCMS in JSON format. The JSON must have these exact keys: name, bg_color, text_color, accent_color, border_color, card_bg, font_family, layout_style, shadow_depth, border_radius, spacing_scale, custom_flourish, sections. Each section in the 'sections' list MUST have three keys: 'title', 'content', and 'section_type'. Valid 'section_type' values are: 'hero', 'features', 'stats', 'cta', 'content'. Output ONLY the JSON object."

  case ffi.run_gemini(system_instruction, prompt) {
    Ok(resp) -> parse_gemini_response(resp)
    Error(e) -> Error(e)
  }
}

fn parse_gemini_response(output: String) -> Result(ThemeConfig, String) {
  // The CLI might output multiple JSON objects. We split by potential top-level starts.
  let parts = string.split(output, "\n{")
  let configs =
    list.filter_map(parts, fn(part) {
      let candidate = case string.starts_with(part, "{") {
        True -> part
        False -> "{" <> part
      }
      case
        json.parse(from: extract_json(candidate), using: theme_config_decoder())
      {
        Ok(config) -> Ok(config)
        Error(_) -> Error(Nil)
      }
    })

  case list.last(configs) {
    Ok(config) -> Ok(sanitize_theme_config(config))
    Error(_) -> Error("Failed to find valid GleamCMS theme config in output.")
  }
}

fn extract_json(input: String) -> String {
  let reversed = string.reverse(input)
  case string.split_once(reversed, "}") {
    Ok(#(_, rest)) -> string.reverse("}" <> rest)
    Error(_) -> input
  }
}

fn theme_config_decoder() {
  use name <- decode.field("name", decode.string)
  use bg_color <- decode.field("bg_color", decode.string)
  use text_color <- decode.field("text_color", decode.string)
  use accent_color <- decode.field("accent_color", decode.string)
  use border_color <- decode.field("border_color", decode.string)
  use card_bg <- decode.field("card_bg", decode.string)
  use font_family <- decode.field("font_family", decode.string)
  use layout_style <- decode.field("layout_style", decode.string)
  use shadow_depth <- decode.field("shadow_depth", decode.string)
  use border_radius <- decode.field("border_radius", decode.string)
  use spacing_scale <- decode.field("spacing_scale", decode.string)
  use custom_flourish <- decode.field("custom_flourish", decode.string)
  use sections <- decode.field("sections", decode.list(section_decoder()))
  decode.success(ThemeConfig(
    name,
    bg_color,
    text_color,
    accent_color,
    border_color,
    card_bg,
    font_family,
    layout_style,
    shadow_depth,
    border_radius,
    spacing_scale,
    custom_flourish,
    sections,
  ))
}

fn section_decoder() {
  use title <- decode.optional_field("title", "Untitled Section", decode.string)
  use content <- decode.optional_field("content", "", decode.string)
  use section_type <- decode.optional_field(
    "section_type",
    "content",
    decode.string,
  )
  decode.success(SectionDescriptor(title, content, section_type))
}

pub fn sanitize_theme_config(config: ThemeConfig) -> ThemeConfig {
  ThemeConfig(
    name: sanitize_text(config.name),
    bg_color: sanitize_color(config.bg_color, "#0f172a"),
    text_color: sanitize_color(config.text_color, "#f8fafc"),
    accent_color: sanitize_color(config.accent_color, "#3b82f6"),
    border_color: sanitize_color(config.border_color, "#1e293b"),
    card_bg: sanitize_color(config.card_bg, "#1e293b99"),
    font_family: sanitize_font(config.font_family),
    layout_style: sanitize_identifier(config.layout_style, "standard"),
    shadow_depth: sanitize_identifier(config.shadow_depth, "subtle"),
    border_radius: sanitize_identifier(config.border_radius, "soft"),
    spacing_scale: sanitize_identifier(config.spacing_scale, "standard"),
    custom_flourish: sanitize_css(config.custom_flourish),
    sections: list.map(config.sections, sanitize_section),
  )
}

fn sanitize_text(input: String) -> String {
  string.trim(input)
}

fn sanitize_color(color: String, default: String) -> String {
  let trimmed = string.trim(color)
  let lower = string.lowercase(trimmed)
  case
    string.starts_with(lower, "#")
    || string.starts_with(lower, "rgb")
    || string.starts_with(lower, "hsl")
  {
    True ->
      case
        string.contains(trimmed, ";")
        || string.contains(lower, "url")
        || string.contains(lower, "expression")
      {
        True -> default
        False -> trimmed
      }
    False -> default
  }
}

fn sanitize_font(font: String) -> String {
  let trimmed = string.trim(font)
  let allowed = [
    "Inter",
    "Roboto",
    "Montserrat",
    "Open Sans",
    "Merriweather",
    "Playfair Display",
    "Fira Code",
    "sans-serif",
    "serif",
    "monospace",
  ]
  case list.contains(allowed, trimmed) {
    True -> trimmed
    False -> "Inter"
  }
}

fn sanitize_identifier(id: String, default: String) -> String {
  let trimmed = string.trim(id)
  let allowed = "abcdefghijklmnopqrstuvwxyz0123456789-"
  case
    trimmed != ""
    && list.all(string.to_graphemes(string.lowercase(trimmed)), fn(c) {
      string.contains(allowed, c)
    })
  {
    True -> trimmed
    False -> default
  }
}

fn sanitize_css(css: String) -> String {
  let lower = string.lowercase(css)
  case
    string.contains(lower, "expression(")
    || string.contains(lower, "@import")
    || string.contains(lower, "<script")
    || string.contains(lower, "javascript:")
  {
    True -> ""
    False -> string.trim(css)
  }
}

fn sanitize_section(sec: SectionDescriptor) -> SectionDescriptor {
  let allowed_types = ["hero", "features", "stats", "cta", "content"]
  let st = case list.contains(allowed_types, sec.section_type) {
    True -> sec.section_type
    False -> "content"
  }
  SectionDescriptor(
    title: string.trim(sec.title),
    content: sec.content,
    section_type: st,
  )
}
