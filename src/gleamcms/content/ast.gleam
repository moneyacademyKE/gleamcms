//// Abstract Syntax Tree definitions for structured content.
//// Deconstructs Markdown and Rich Text into typed, immutable values.

pub type Inline {
  Text(content: String)
  Bold(children: List(Inline))
  Italic(children: List(Inline))
  Code(content: String)
  Link(text: String, href: String)
  Image(alt: String, src: String)
}

pub type Block {
  Heading(level: Int, children: List(Inline))
  Paragraph(children: List(Inline))
  CodeBlock(language: String, code: String)
  BlockQuote(children: List(Inline))
  UnorderedList(items: List(List(Inline)))
  OrderedList(items: List(List(Inline)))
  HorizontalRule
}

pub type Document {
  Document(blocks: List(Block))
}
