/// Colorized renderer for unified `Diagnostic`s.
///
/// Reads from `caffeine_cli/diagnostic.Diagnostic` so that one renderer
/// drives both the `caffeine_lang` errors we already emit and a future
/// `caffeine_lsp` migration onto the same shape. The `render_all/2`
/// wrapper kept here for back-compat converts `CompilationError`s on
/// the way in.
import caffeine_cli/color.{type ColorMode}
import caffeine_cli/diagnostic.{type Diagnostic, type Severity, type Span}
import caffeine_lang/errors.{type CompilationError}
import caffeine_lang/source_snippet
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string

/// Render a single diagnostic with ANSI color codes.
pub fn render(diagnostic: Diagnostic, color_mode: ColorMode) -> String {
  let code_str = diagnostic.code_to_string(diagnostic.code)
  let severity_word = severity_word(diagnostic.severity)

  let header =
    color.bold(
      severity_color(diagnostic.severity, severity_word <> "[" <> code_str <> "]", color_mode),
      color_mode,
    )
    <> ": "
    <> diagnostic.message

  let location_line = case diagnostic.primary_span(diagnostic) {
    Some(span) -> Some(format_location(span, color_mode))
    None -> None
  }

  let snippet = case diagnostic.source, diagnostic.primary_span(diagnostic) {
    Some(content), Some(span) -> Some(format_snippet(content, span, color_mode))
    _, _ -> None
  }

  let help_lines =
    list.map(diagnostic.helps, fn(h) { format_help(h, color_mode) })

  let note_lines =
    list.map(diagnostic.notes, fn(n) { format_note(n, color_mode) })

  let explain_line =
    Some(format_explain(code_str, color_mode))

  [Some(header), location_line, snippet]
  |> list.append(list.map(help_lines, Some))
  |> list.append(list.map(note_lines, Some))
  |> list.append([explain_line])
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
) -> String {
  diagnostics
  |> list.map(render(_, color_mode))
  |> string.join("\n\n")
}

/// Back-compat: render a list of `CompilationError`s by mapping through
/// `Diagnostic`. Existing callers in `handler.gleam` keep working.
pub fn render_all(
  errors: List(CompilationError),
  color_mode: ColorMode,
) -> String {
  errors
  |> list.map(diagnostic.from_compilation_error)
  |> render_diagnostics(color_mode)
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

// --- Location header ---

fn format_location(span: Span, color_mode: ColorMode) -> String {
  let path_str = case span.file {
    Some(p) -> p
    None -> "<unknown>"
  }
  let coords = case span.start.line, span.start.column {
    0, 0 -> path_str
    line, col ->
      path_str <> ":" <> int.to_string(line) <> ":" <> int.to_string(col)
  }
  "  " <> color.blue("--> ", color_mode) <> color.cyan(coords, color_mode)
}

// --- Snippet ---

fn format_snippet(
  content: String,
  span: Span,
  color_mode: ColorMode,
) -> String {
  let end_column = case span.end.column == span.start.column {
    True -> None
    False -> Some(span.end.column)
  }
  let snippet =
    source_snippet.extract_snippet(
      content,
      span.start.line,
      span.start.column,
      end_column,
    )
  snippet.rendered
  |> string.split("\n")
  |> list.map(fn(line) { colorize_snippet_line(line, color_mode) })
  |> string.join("\n")
}

fn colorize_snippet_line(line: String, color_mode: ColorMode) -> String {
  case is_marker_line(line) {
    True -> color.bold(color.red(line, color_mode), color_mode)
    False ->
      case string.split_once(line, " | ") {
        Ok(#(gutter, content)) ->
          color.blue(gutter, color_mode) <> " | " <> content
        Error(_) -> line
      }
  }
}

fn is_marker_line(line: String) -> Bool {
  string.contains(line, "^")
  && {
    line
    |> string.to_graphemes
    |> list.all(fn(c) { c == " " || c == "|" || c == "^" })
  }
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

