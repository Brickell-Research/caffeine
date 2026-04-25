/// Colorized renderer for unified `Diagnostic`s.
///
/// Reads from `caffeine_cli/diagnostic.Diagnostic` so that one renderer
/// drives both the `caffeine_lang` errors we already emit and a future
/// `caffeine_lsp` migration onto the same shape. The `render_all/3`
/// wrapper kept here for back-compat converts `CompilationError`s on
/// the way in.
///
/// Snippet layout (themed, Unicode-capable terminal):
///
///     error[E103]: unexpected token
///       ╭─[expectations/checkout.caf:14:8]
///       │
///    12 │   slo {
///    13 │     window: 30d
///    14 │     foo: "bar"
///       │            ━ here
///    15 │   }
///       ╰──
///        = help: Did you mean 'foo'?
///        = help: run `caffeine explain E103` for more on this error
///
/// ASCII fallback swaps `╭─ │ ╰─ ━` for `,- | '- ^`.
import caffeine_cli/color.{type ColorMode}
import caffeine_cli/diagnostic.{type Diagnostic, type Severity, type Span}
import caffeine_lang/errors.{type CompilationError}
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string

/// Render a single diagnostic with ANSI color codes.
pub fn render(
  diagnostic: Diagnostic,
  color_mode: ColorMode,
  unicode: Bool,
) -> String {
  let code_str = diagnostic.code_to_string(diagnostic.code)
  let severity_word = severity_word(diagnostic.severity)

  let header =
    color.bold(
      severity_color(
        diagnostic.severity,
        severity_word <> "[" <> code_str <> "]",
        color_mode,
      ),
      color_mode,
    )
    <> ": "
    <> diagnostic.message

  let primary = diagnostic.primary_span(diagnostic)

  let snippet_block = case diagnostic.source, primary {
    Some(content), Some(span) ->
      Some(format_snippet_block(
        content,
        span,
        diagnostic.severity,
        color_mode,
        unicode,
      ))
    _, Some(span) ->
      // No source available — still surface a one-line location pointer.
      Some(format_location_only(span, color_mode, unicode))
    _, None -> None
  }

  let help_lines = list.map(diagnostic.helps, fn(h) { format_help(h, color_mode) })
  let note_lines = list.map(diagnostic.notes, fn(n) { format_note(n, color_mode) })
  let explain_line = format_explain(code_str, color_mode)

  let parts =
    [Some(header), snippet_block]
    |> list.append(list.map(help_lines, Some))
    |> list.append(list.map(note_lines, Some))
    |> list.append([Some(explain_line)])

  parts
  |> list.filter_map(fn(opt) {
    case opt {
      Some(val) -> Ok(val)
      None -> Error(Nil)
    }
  })
  |> string.join("\n")
}

/// Render multiple diagnostics, separated by blank lines.
pub fn render_diagnostics(
  diagnostics: List(Diagnostic),
  color_mode: ColorMode,
  unicode: Bool,
) -> String {
  diagnostics
  |> list.map(render(_, color_mode, unicode))
  |> string.join("\n\n")
}

/// Back-compat: render a list of `CompilationError`s by mapping through
/// `Diagnostic`. Existing callers in `handler.gleam` keep working.
pub fn render_all(
  errors: List(CompilationError),
  color_mode: ColorMode,
  unicode: Bool,
) -> String {
  errors
  |> list.map(diagnostic.from_compilation_error)
  |> render_diagnostics(color_mode, unicode)
}

// --- Severity ---

fn severity_word(severity: Severity) -> String {
  case severity {
    diagnostic.Error -> "error"
    diagnostic.Warning -> "warning"
    diagnostic.Note -> "note"
    diagnostic.Help -> "help"
  }
}

fn severity_color(
  severity: Severity,
  text: String,
  color_mode: ColorMode,
) -> String {
  case severity {
    diagnostic.Error -> color.red(text, color_mode)
    diagnostic.Warning -> color.yellow(text, color_mode)
    diagnostic.Note -> color.cyan(text, color_mode)
    diagnostic.Help -> color.cyan(text, color_mode)
  }
}

// --- Box glyphs ---

type SnippetGlyphs {
  SnippetGlyphs(
    top_left: String,
    bottom_left: String,
    horizontal: String,
    vertical: String,
    underline: String,
  )
}

fn glyphs_for(unicode: Bool) -> SnippetGlyphs {
  case unicode {
    True ->
      SnippetGlyphs(
        top_left: "╭─",
        bottom_left: "╰─",
        horizontal: "─",
        vertical: "│",
        underline: "━",
      )
    False ->
      SnippetGlyphs(
        top_left: ",-",
        bottom_left: "'-",
        horizontal: "-",
        vertical: "|",
        underline: "^",
      )
  }
}

// --- Snippet block ---

const context_above: Int = 2
const context_below: Int = 1

fn format_snippet_block(
  content: String,
  span: Span,
  severity: Severity,
  color_mode: ColorMode,
  unicode: Bool,
) -> String {
  let glyphs = glyphs_for(unicode)
  let header_line = format_box_header(span, glyphs, color_mode)

  let center_line = span.start.line
  let lines = extract_window(content, center_line, context_above, context_below)
  let max_line_num = case list.last(lines) {
    Ok(#(n, _)) -> n
    Error(_) -> center_line + context_below
  }
  let gutter_width = string.length(int.to_string(max_line_num))
  let empty_gutter = string.repeat(" ", gutter_width)

  let body_lines =
    lines
    |> list.map(fn(pair) {
      let #(line_num, text) = pair
      let formatted =
        format_source_line(line_num, text, gutter_width, glyphs, color_mode)
      case line_num == center_line {
        True ->
          formatted
          <> "\n"
          <> format_underline(
            span,
            empty_gutter,
            severity,
            glyphs,
            color_mode,
          )
        False -> formatted
      }
    })

  let opening_pipe =
    "  "
    <> empty_gutter
    <> " "
    <> color.dim(glyphs.vertical, color_mode)
  let closing_pipe =
    "  "
    <> empty_gutter
    <> " "
    <> color.dim(glyphs.bottom_left <> glyphs.horizontal, color_mode)

  string.join(
    list.flatten([[header_line, opening_pipe], body_lines, [closing_pipe]]),
    "\n",
  )
}

fn format_box_header(
  span: Span,
  glyphs: SnippetGlyphs,
  color_mode: ColorMode,
) -> String {
  let coords = format_coords(span)
  "  "
  <> color.dim(glyphs.top_left <> "[", color_mode)
  <> color.cyan(coords, color_mode)
  <> color.dim("]", color_mode)
}

fn format_location_only(
  span: Span,
  color_mode: ColorMode,
  unicode: Bool,
) -> String {
  let glyphs = glyphs_for(unicode)
  format_box_header(span, glyphs, color_mode)
}

fn format_coords(span: Span) -> String {
  let path = case span.file {
    Some(p) -> p
    None -> "<unknown>"
  }
  case span.start.line, span.start.column {
    0, 0 -> path
    line, col ->
      path <> ":" <> int.to_string(line) <> ":" <> int.to_string(col)
  }
}

/// Render a single source line with line-number gutter, using the
/// surrounding box's vertical glyph so Unicode and ASCII renderings
/// stay internally consistent.
fn format_source_line(
  line_num: Int,
  text: String,
  gutter_width: Int,
  glyphs: SnippetGlyphs,
  color_mode: ColorMode,
) -> String {
  let num_str = int.to_string(line_num)
  let pad = string.repeat(" ", gutter_width - string.length(num_str))
  "  "
  <> pad
  <> color.dim(num_str, color_mode)
  <> " "
  <> color.dim(glyphs.vertical, color_mode)
  <> " "
  <> text
}

fn format_underline(
  span: Span,
  empty_gutter: String,
  severity: Severity,
  glyphs: SnippetGlyphs,
  color_mode: ColorMode,
) -> String {
  let column_pad = string.repeat(" ", int.max(0, span.start.column - 1))
  let span_width = int.max(1, span.end.column - span.start.column)
  let underline = string.repeat(glyphs.underline, span_width)
  let label = case span.label {
    Some(l) -> " " <> l
    None -> ""
  }
  "  "
  <> empty_gutter
  <> " "
  <> color.dim(glyphs.vertical, color_mode)
  <> " "
  <> column_pad
  <> color.bold(severity_color(severity, underline <> label, color_mode), color_mode)
}

/// Extract `(line_number, line_content)` pairs around `center_line`,
/// 1-indexed. Lines outside the file's range are silently skipped.
fn extract_window(
  content: String,
  center_line: Int,
  before: Int,
  after: Int,
) -> List(#(Int, String)) {
  let start = int.max(1, center_line - before)
  let stop = center_line + after
  content
  |> string.split("\n")
  |> list.index_map(fn(text, idx) { #(idx + 1, text) })
  |> list.filter(fn(pair) { pair.0 >= start && pair.0 <= stop })
}

// --- Help / note / explain footers ---

fn format_help(text: String, color_mode: ColorMode) -> String {
  "   " <> color.cyan("= help:", color_mode) <> " " <> text
}

fn format_note(text: String, color_mode: ColorMode) -> String {
  "   " <> color.cyan("= note:", color_mode) <> " " <> text
}

fn format_explain(code_str: String, color_mode: ColorMode) -> String {
  "   "
  <> color.cyan("= help:", color_mode)
  <> " run `"
  <> color.green("caffeine explain " <> code_str, color_mode)
  <> "` for more on this error"
}
