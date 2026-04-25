import caffeine_cli/color
import caffeine_cli/explanations
import caffeine_lang/errors
import gleam/list
import gleam/string
import gleeunit/should

const off = color.ColorDisabled

// --- Coverage: every error code in caffeine_lang has a prose entry ---
// If this test fails after adding a new variant to CompilationError,
// add the matching Explanation entry in explanations.gleam.

pub fn every_known_error_code_has_explanation_test() {
  let sample_errors = [
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

  list.each(sample_errors, fn(err) {
    let code = errors.error_code_to_string(errors.error_code_for(err))
    case explanations.lookup(code) {
      Ok(_) -> Nil
      Error(_) -> panic as { "no explanation registered for " <> code }
    }
  })
}

// --- Lookup semantics ---

pub fn lookup_uppercase_test() {
  explanations.lookup("E100") |> should.be_ok
}

pub fn lookup_lowercase_test() {
  // Codes match case-insensitively so `caffeine explain e100` works.
  explanations.lookup("e100") |> should.be_ok
}

pub fn lookup_unknown_test() {
  explanations.lookup("E999") |> should.be_error
  explanations.lookup("") |> should.be_error
}

// --- known_codes ---

pub fn known_codes_are_sorted_test() {
  let codes = explanations.known_codes()
  let sorted = list.sort(codes, string.compare)
  codes |> should.equal(sorted)
}

pub fn known_codes_includes_core_errors_test() {
  let codes = explanations.known_codes()
  ["E100", "E200", "E303", "E501"]
  |> list.each(fn(expected) {
    case list.contains(codes, expected) {
      True -> Nil
      False -> panic as { "expected " <> expected <> " in known codes" }
    }
  })
}

// --- Render ---

pub fn render_includes_code_and_title_test() {
  let assert Ok(e) = explanations.lookup("E100")
  let out = explanations.render(e, off)
  string.contains(out, "E100") |> should.be_true
  string.contains(out, "parse error") |> should.be_true
}

pub fn render_includes_causes_when_present_test() {
  let assert Ok(e) = explanations.lookup("E100")
  let out = explanations.render(e, off)
  string.contains(out, "Common causes:") |> should.be_true
}

pub fn render_includes_fix_section_test() {
  let assert Ok(e) = explanations.lookup("E100")
  let out = explanations.render(e, off)
  string.contains(out, "How to fix:") |> should.be_true
}

pub fn render_includes_docs_link_when_set_test() {
  let assert Ok(e) = explanations.lookup("E100")
  let out = explanations.render(e, off)
  string.contains(out, "https://caffeine.brickellresearch.org/errors/E100")
  |> should.be_true
}

pub fn render_color_off_has_no_escapes_test() {
  let assert Ok(e) = explanations.lookup("E100")
  let out = explanations.render(e, off)
  string.contains(out, "\u{001b}[") |> should.be_false
}
