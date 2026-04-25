/// Unified diagnostic data model for the CLI.
///
/// This is the shape `error_presenter.gleam` renders, the shape a future
/// `--format=json` will serialize, and the shape a future
/// `--format=github` will project into GitHub Actions workflow commands.
/// It's modeled on rustc's diagnostic JSON (see
/// https://doc.rust-lang.org/rustc/json.html) because that format has
/// converged across LSPs, CI tools, and IDEs over the last decade.
///
/// `caffeine_lang.errors.CompilationError` lives in a separate published
/// package, so for now this type is CLI-local. Once the LSP wants to
/// emit the same shape, this module can be lifted into `caffeine_lang`
/// and the LSP's parallel `Diagnostic` type can be replaced — see §4.2
/// of the CLI design proposal.
import caffeine_lang/errors.{type CompilationError}
import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/string

/// Severity of a diagnostic. Mirrors the LSP enum (`Error`/`Warning`/
/// `Information`/`Hint`) but uses Gleam-idiomatic names.
pub type Severity {
  Error
  Warning
  Note
  Help
}

/// 1-indexed line + column. We drop the byte_offset rustc carries
/// because `caffeine_lang`'s `SourceLocation` doesn't currently track
/// it; recover it later when we need precise editor edits.
pub type Position {
  Position(line: Int, column: Int)
}

/// A region of source text relevant to a diagnostic. The primary span
/// (first one with `is_primary: True`) is the focus; secondary spans
/// give supporting context (e.g. "expected here", "see prior definition").
pub type Span {
  Span(
    file: Option(String),
    start: Position,
    end: Position,
    is_primary: Bool,
    label: Option(String),
  )
}

/// How safely an automated tool can apply a suggestion. Matches rustc's
/// `suggestion_applicability` enum so the `--message-format=json` we
/// emit later interoperates with existing rustc-aware tooling.
pub type Applicability {
  MachineApplicable
  MaybeIncorrect
  HasPlaceholders
  Unspecified
}

/// A structured fix the user (or a tool) could apply.
pub type Suggestion {
  Suggestion(
    span: Span,
    replacement: String,
    applicability: Applicability,
    description: Option(String),
  )
}

/// Hard errors get short numeric codes (`E100`, `E303`); future lints
/// will get hierarchical slugs (`caffeine/window/missing-default`).
pub type ErrorCode {
  HardError(prefix: String, number: Int)
  Lint(category: String, rule: String)
}

/// A single diagnostic. `source` carries the raw file contents when
/// available so the renderer can extract snippets without a second
/// trip through the file system.
pub type Diagnostic {
  Diagnostic(
    code: ErrorCode,
    severity: Severity,
    message: String,
    spans: List(Span),
    notes: List(String),
    helps: List(String),
    suggestions: List(Suggestion),
    docs_url: Option(String),
    source: Option(String),
  )
}

/// Render an error code as the wire string consumers see (`E103`,
/// `caffeine/window/missing-default`).
pub fn code_to_string(code: ErrorCode) -> String {
  case code {
    HardError(_prefix, number) -> "E" <> pad3(number)
    Lint(category, rule) -> "caffeine/" <> category <> "/" <> rule
  }
}

fn pad3(n: Int) -> String {
  let s = int.to_string(n)
  case string.length(s) {
    1 -> "00" <> s
    2 -> "0" <> s
    _ -> s
  }
}

// --- Mapping from CompilationError ---

/// Convert a `caffeine_lang` compilation error into the unified
/// `Diagnostic` shape. All current `CompilationError` variants are
/// modeled as severity `Error`; warnings travel through a separate
/// `compile_presenter.gleam` channel today.
pub fn from_compilation_error(err: CompilationError) -> Diagnostic {
  let context = errors.error_context(err)
  let raw_code = errors.error_code_for(err)
  let code = HardError(prefix: raw_code.phase, number: raw_code.number)
  let code_str = code_to_string(code)

  let spans = build_spans(context)
  let helps = build_helps(context)

  Diagnostic(
    code: code,
    severity: Error,
    message: errors.to_message(err),
    spans: spans,
    notes: [],
    helps: helps,
    suggestions: [],
    docs_url: Some(docs_root <> code_str),
    source: context.source_content,
  )
}

const docs_root: String = "https://caffeine.brickellresearch.org/errors/"

fn build_spans(context: errors.ErrorContext) -> List(Span) {
  case context.source_path, context.location {
    Some(path), Some(loc) -> {
      let end_col = option.unwrap(loc.end_column, loc.column + 1)
      [
        Span(
          file: Some(path),
          start: Position(line: loc.line, column: loc.column),
          end: Position(line: loc.line, column: end_col),
          is_primary: True,
          label: None,
        ),
      ]
    }
    Some(path), None -> [
      // No location info, but we know which file — useful for the
      // `--> path` line even without a snippet.
      Span(
        file: Some(path),
        start: Position(line: 0, column: 0),
        end: Position(line: 0, column: 0),
        is_primary: True,
        label: None,
      ),
    ]
    None, _ -> []
  }
}

fn build_helps(context: errors.ErrorContext) -> List(String) {
  case context.suggestion {
    Some(s) -> ["Did you mean '" <> s <> "'?"]
    None -> []
  }
}

/// Find the primary span (the one the diagnostic is "about"). Returns
/// the first span marked primary, or the first span overall, or None
/// when there are no spans at all.
pub fn primary_span(diagnostic: Diagnostic) -> Option(Span) {
  case diagnostic.spans {
    [] -> None
    spans ->
      case find_first_primary(spans) {
        Some(s) -> Some(s)
        None ->
          case spans {
            [first, ..] -> Some(first)
            [] -> None
          }
      }
  }
}

fn find_first_primary(spans: List(Span)) -> Option(Span) {
  case spans {
    [] -> None
    [s, ..rest] ->
      case s.is_primary {
        True -> Some(s)
        False -> find_first_primary(rest)
      }
  }
}
