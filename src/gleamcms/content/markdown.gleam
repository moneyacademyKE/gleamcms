import gleam/int
import gleam/list
import gleam/string
import gleamcms/content/ast.{
  type Block, type Document, type Inline, BlockQuote, Bold, Code, CodeBlock,
  Document, Heading, HorizontalRule, Image, Italic, Link, OrderedList, Paragraph,
  Text, UnorderedList,
}

pub fn parse(input: String) -> Document {
  let lines = string.split(input, "\n")
  let blocks = parse_lines(lines, [])
  Document(blocks: blocks)
}

fn parse_lines(lines: List(String), acc: List(Block)) -> List(Block) {
  case lines {
    [] -> list.reverse(acc)
    ["```" <> lang, ..rest] -> {
      let #(code_lines, remaining) = collect_code_block(rest, [])
      let block =
        CodeBlock(
          language: string.trim(lang),
          code: string.join(code_lines, "\n"),
        )
      parse_lines(remaining, [block, ..acc])
    }
    [line, ..rest] -> {
      let trimmed = string.trim(line)
      case trimmed {
        "" -> parse_lines(rest, acc)
        "---" | "***" | "___" -> parse_lines(rest, [HorizontalRule, ..acc])
        "# " <> text ->
          parse_lines(rest, [Heading(1, parse_inlines(text)), ..acc])
        "## " <> text ->
          parse_lines(rest, [Heading(2, parse_inlines(text)), ..acc])
        "### " <> text ->
          parse_lines(rest, [Heading(3, parse_inlines(text)), ..acc])
        "#### " <> text ->
          parse_lines(rest, [Heading(4, parse_inlines(text)), ..acc])
        "##### " <> text ->
          parse_lines(rest, [Heading(5, parse_inlines(text)), ..acc])
        "###### " <> text ->
          parse_lines(rest, [Heading(6, parse_inlines(text)), ..acc])
        "> " <> text ->
          parse_lines(rest, [BlockQuote(parse_inlines(text)), ..acc])
        "- " <> _ | "* " <> _ -> {
          let #(items, remaining) = collect_unordered_list([line, ..rest], [])
          parse_lines(remaining, [UnorderedList(items), ..acc])
        }
        "1. " <> _ -> {
          let #(items, remaining) = collect_ordered_list([line, ..rest], [])
          parse_lines(remaining, [OrderedList(items), ..acc])
        }
        _ -> parse_lines(rest, [Paragraph(parse_inlines(trimmed)), ..acc])
      }
    }
  }
}

fn collect_code_block(
  lines: List(String),
  acc: List(String),
) -> #(List(String), List(String)) {
  case lines {
    [] -> #(list.reverse(acc), [])
    ["```", ..rest] -> #(list.reverse(acc), rest)
    [line, ..rest] -> collect_code_block(rest, [line, ..acc])
  }
}

fn collect_unordered_list(
  lines: List(String),
  acc: List(List(Inline)),
) -> #(List(List(Inline)), List(String)) {
  case lines {
    ["- " <> item, ..rest] | ["* " <> item, ..rest] ->
      collect_unordered_list(rest, [parse_inlines(string.trim(item)), ..acc])
    _ -> #(list.reverse(acc), lines)
  }
}

fn collect_ordered_list(
  lines: List(String),
  acc: List(List(Inline)),
) -> #(List(List(Inline)), List(String)) {
  case lines {
    [line, ..rest] -> {
      case is_ordered_item(line) {
        Ok(item) -> collect_ordered_list(rest, [parse_inlines(item), ..acc])
        Error(_) -> #(list.reverse(acc), lines)
      }
    }
    [] -> #(list.reverse(acc), [])
  }
}

fn is_ordered_item(line: String) -> Result(String, Nil) {
  let trimmed = string.trim(line)
  case string.split_once(trimmed, ". ") {
    Ok(#(num, rest)) ->
      case int.parse(num) {
        Ok(_) -> Ok(string.trim(rest))
        Error(_) -> Error(Nil)
      }
    Error(_) -> Error(Nil)
  }
}

pub fn parse_inlines(text: String) -> List(Inline) {
  tokenize_inlines(text)
}

fn tokenize_inlines(text: String) -> List(Inline) {
  case text {
    "" -> []
    "![" <> rest ->
      case string.split_once(rest, "](") {
        Ok(#(alt, after_alt)) ->
          case extract_paren_target(after_alt) {
            Ok(#(src, remaining)) -> [
              Image(alt: alt, src: sanitize_url(src)),
              ..tokenize_inlines(remaining)
            ]
            Error(_) -> [Text("![" <> rest)]
          }
        Error(_) -> [Text("![" <> rest)]
      }
    "[" <> rest ->
      case string.split_once(rest, "](") {
        Ok(#(link_text, after_text)) ->
          case extract_paren_target(after_text) {
            Ok(#(href, remaining)) -> [
              Link(text: link_text, href: sanitize_url(href)),
              ..tokenize_inlines(remaining)
            ]
            Error(_) -> [Text("[" <> rest)]
          }
        Error(_) -> [Text("[" <> rest)]
      }
    "`" <> rest ->
      case string.split_once(rest, "`") {
        Ok(#(code, remaining)) -> [Code(code), ..tokenize_inlines(remaining)]
        Error(_) -> [Text("`" <> rest)]
      }
    "**" <> rest ->
      case string.split_once(rest, "**") {
        Ok(#(bold_text, remaining)) -> [
          Bold(tokenize_inlines(bold_text)),
          ..tokenize_inlines(remaining)
        ]
        Error(_) -> [Text("**" <> rest)]
      }
    "*" <> rest ->
      case string.split_once(rest, "*") {
        Ok(#(italic_text, remaining)) -> [
          Italic(tokenize_inlines(italic_text)),
          ..tokenize_inlines(remaining)
        ]
        Error(_) -> [Text("*" <> rest)]
      }
    _ -> {
      let next_special = find_next_special(text)
      case next_special {
        #(plain, "") -> [Text(plain)]
        #(plain, special) -> [Text(plain), ..tokenize_inlines(special)]
      }
    }
  }
}

fn find_next_special(text: String) -> #(String, String) {
  let chars = string.to_graphemes(text)
  find_special_acc(chars, "")
}

fn find_special_acc(chars: List(String), acc: String) -> #(String, String) {
  case chars {
    [] -> #(acc, "")
    ["!", "[", ..] | ["[", ..] | ["`", ..] | ["*", "*", ..] | ["*", ..] -> #(
      acc,
      string.join(chars, ""),
    )
    [c, ..rest] -> find_special_acc(rest, acc <> c)
  }
}

fn extract_paren_target(input: String) -> Result(#(String, String), Nil) {
  extract_paren_acc(string.to_graphemes(input), 0, "")
}

fn extract_paren_acc(
  chars: List(String),
  depth: Int,
  acc: String,
) -> Result(#(String, String), Nil) {
  case chars {
    [] -> Error(Nil)
    [")", ..rest] if depth == 0 -> Ok(#(acc, string.join(rest, "")))
    [")", ..rest] -> extract_paren_acc(rest, depth - 1, acc <> ")")
    ["(", ..rest] -> extract_paren_acc(rest, depth + 1, acc <> "(")
    [c, ..rest] -> extract_paren_acc(rest, depth, acc <> c)
  }
}

pub fn sanitize_url(url: String) -> String {
  let trimmed = string.trim(url)
  let lower = string.lowercase(trimmed)
  case
    string.starts_with(lower, "http://")
    || string.starts_with(lower, "https://")
    || string.starts_with(lower, "/")
    || string.starts_with(lower, "mailto:")
    || string.starts_with(lower, "#")
  {
    True -> trimmed
    False -> "#"
  }
}

pub fn escape_html(text: String) -> String {
  text
  |> string.replace("&", "&amp;")
  |> string.replace("<", "&lt;")
  |> string.replace(">", "&gt;")
  |> string.replace("\"", "&quot;")
  |> string.replace("'", "&#39;")
}

pub fn to_html(doc: Document) -> String {
  doc.blocks
  |> list.map(block_to_html)
  |> string.join("\n")
}

fn block_to_html(block: Block) -> String {
  case block {
    Heading(level, inlines) -> {
      let tag = "h" <> int.to_string(level)
      "<" <> tag <> ">" <> inlines_to_html(inlines) <> "</" <> tag <> ">"
    }
    Paragraph(inlines) -> "<p>" <> inlines_to_html(inlines) <> "</p>"
    CodeBlock(lang, code) -> {
      let class_attr = case lang {
        "" -> ""
        l -> " class=\"language-" <> escape_html(l) <> "\""
      }
      "<pre><code" <> class_attr <> ">" <> escape_html(code) <> "</code></pre>"
    }
    BlockQuote(inlines) ->
      "<blockquote>" <> inlines_to_html(inlines) <> "</blockquote>"
    UnorderedList(items) -> {
      let li_html =
        items
        |> list.map(fn(item) { "<li>" <> inlines_to_html(item) <> "</li>" })
        |> string.join("")
      "<ul>" <> li_html <> "</ul>"
    }
    OrderedList(items) -> {
      let li_html =
        items
        |> list.map(fn(item) { "<li>" <> inlines_to_html(item) <> "</li>" })
        |> string.join("")
      "<ol>" <> li_html <> "</ol>"
    }
    HorizontalRule -> "<hr />"
  }
}

fn inlines_to_html(inlines: List(Inline)) -> String {
  inlines
  |> list.map(inline_to_html)
  |> string.join("")
}

fn inline_to_html(inline: Inline) -> String {
  case inline {
    Text(content) -> escape_html(content)
    Bold(children) -> "<strong>" <> inlines_to_html(children) <> "</strong>"
    Italic(children) -> "<em>" <> inlines_to_html(children) <> "</em>"
    Code(content) -> "<code>" <> escape_html(content) <> "</code>"
    Link(text, href) ->
      "<a href=\"" <> escape_html(href) <> "\">" <> escape_html(text) <> "</a>"
    Image(alt, src) ->
      "<img src=\""
      <> escape_html(src)
      <> "\" alt=\""
      <> escape_html(alt)
      <> "\" />"
  }
}
