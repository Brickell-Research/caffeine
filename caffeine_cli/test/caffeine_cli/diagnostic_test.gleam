import caffeine_cli/diagnostic
import caffeine_lang/errors
import gleam/list
import gleam/option.{None, Some}
import gleeunit/should

// --- code_to_string ---

pub fn code_to_string_pads_hard_errors_test() {
  diagnostic.code_to_string(diagnostic.HardError("parse", 100))
  |> should.equal("E100")
  diagnostic.code_to_string(diagnostic.HardError("linker", 30))
  |> should.equal("E030")
  diagnostic.code_to_string(diagnostic.HardError("semantic", 7))
  |> should.equal("E007")
}

pub fn code_to_string_does_not_pad_4_digit_test() {
  diagnostic.code_to_string(diagnostic.HardError("custom", 1234))
  |> should.equal("E1234")
}

pub fn code_to_string_lint_uses_slash_format_test() {
  diagnostic.code_to_string(diagnostic.Lint("window", "missing-default"))
  |> should.equal("caffeine/window/missing-default")
}

// --- from_compilation_error ---

pub fn from_compilation_error_carries_message_test() {
  let err = errors.frontend_parse_error("unexpected token")
  let d = diagnostic.from_compilation_error(err)
  d.message |> should.equal("unexpected token")
}

pub fn from_compilation_error_carries_code_test() {
  let err = errors.frontend_parse_error("_")
  let d = diagnostic.from_compilation_error(err)
  diagnostic.code_to_string(d.code) |> should.equal("E100")
}

pub fn from_compilation_error_severity_is_error_test() {
  // All current CompilationError variants map to Error severity.
  let err = errors.linker_duplicate_error("dup")
  let d = diagnostic.from_compilation_error(err)
  d.severity |> should.equal(diagnostic.Error)
}

pub fn from_compilation_error_no_location_yields_empty_spans_test() {
  // When the underlying error has no path or location info, no spans
  // are synthesized — the renderer can still show the header.
  let err = errors.cql_parser_error("CQL boom")
  let d = diagnostic.from_compilation_error(err)
  d.spans |> should.equal([])
}

pub fn from_compilation_error_emits_docs_url_test() {
  let err = errors.frontend_parse_error("_")
  let d = diagnostic.from_compilation_error(err)
  d.docs_url
  |> should.equal(Some("https://caffeine.brickellresearch.org/errors/E100"))
}

// --- primary_span ---

pub fn primary_span_picks_marked_primary_test() {
  let secondary =
    diagnostic.Span(
      file: Some("a.caf"),
      start: diagnostic.Position(1, 1),
      end: diagnostic.Position(1, 2),
      is_primary: False,
      label: None,
    )
  let primary =
    diagnostic.Span(
      file: Some("b.caf"),
      start: diagnostic.Position(2, 1),
      end: diagnostic.Position(2, 5),
      is_primary: True,
      label: None,
    )
  let d =
    diagnostic.Diagnostic(
      code: diagnostic.HardError("parse", 100),
      severity: diagnostic.Error,
      message: "test",
      spans: [secondary, primary],
      notes: [],
      helps: [],
      suggestions: [],
      docs_url: None,
      source: None,
    )
  case diagnostic.primary_span(d) {
    Some(span) -> span.file |> should.equal(Some("b.caf"))
    None -> panic as "expected primary span"
  }
}

pub fn primary_span_falls_back_to_first_when_none_marked_test() {
  let only =
    diagnostic.Span(
      file: Some("z.caf"),
      start: diagnostic.Position(1, 1),
      end: diagnostic.Position(1, 2),
      is_primary: False,
      label: None,
    )
  let d =
    diagnostic.Diagnostic(
      code: diagnostic.HardError("parse", 100),
      severity: diagnostic.Error,
      message: "test",
      spans: [only],
      notes: [],
      helps: [],
      suggestions: [],
      docs_url: None,
      source: None,
    )
  case diagnostic.primary_span(d) {
    Some(span) -> span.file |> should.equal(Some("z.caf"))
    None -> panic as "expected fallback span"
  }
}

pub fn primary_span_none_when_no_spans_test() {
  let d =
    diagnostic.Diagnostic(
      code: diagnostic.HardError("parse", 100),
      severity: diagnostic.Error,
      message: "test",
      spans: [],
      notes: [],
      helps: [],
      suggestions: [],
      docs_url: None,
      source: None,
    )
  diagnostic.primary_span(d) |> should.equal(None)
}

// --- coverage check: every CompilationError maps without panicking ---

pub fn every_error_variant_maps_test() {
  let samples = [
    errors.frontend_parse_error("_"),
    errors.frontend_validation_error("_"),
    errors.linker_parse_error("_"),
    errors.linker_value_validation_error("_"),
    errors.linker_duplicate_error("_"),
    errors.linker_vendor_resolution_error("_"),
    errors.semantic_analysis_template_parse_error("_"),
    errors.semantic_analysis_template_resolution_error("_"),
    errors.semantic_analysis_dependency_validation_error("_"),
    errors.generator_slo_query_resolution_error("_"),
    errors.cql_resolver_error("_"),
    errors.cql_parser_error("_"),
  ]
  list.each(samples, fn(err) {
    let d = diagnostic.from_compilation_error(err)
    // Every diagnostic should at least carry severity Error and a code
    // string that's non-empty.
    d.severity |> should.equal(diagnostic.Error)
    case diagnostic.code_to_string(d.code) {
      "" -> panic as "empty code string"
      _ -> Nil
    }
  })
}
