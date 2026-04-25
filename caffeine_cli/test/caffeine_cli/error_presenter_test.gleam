import caffeine_cli/color
import caffeine_cli/diagnostic
import caffeine_cli/error_presenter
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should

const off = color.ColorDisabled

const sample_source: String = "line 1
line 2
line 3 BAD HERE
line 4
line 5"

fn sample_diagnostic() -> diagnostic.Diagnostic {
  diagnostic.Diagnostic(
    code: diagnostic.HardError("parse", 100),
    severity: diagnostic.Error,
    message: "unexpected token",
    spans: [
      diagnostic.Span(
        file: Some("src/main.caf"),
        start: diagnostic.Position(line: 3, column: 8),
        end: diagnostic.Position(line: 3, column: 11),
        is_primary: True,
        label: Some("here"),
      ),
    ],
    notes: [],
    helps: ["Did you mean 'foo'?"],
    suggestions: [],
    docs_url: None,
    source: Some(sample_source),
  )
}

// --- Header ---

pub fn render_includes_severity_and_code_test() {
  let out = error_presenter.render(sample_diagnostic(), off, True)
  string.contains(out, "error[E100]") |> should.be_true
  string.contains(out, "unexpected token") |> should.be_true
}

// --- Snippet structure (Unicode mode) ---

pub fn render_unicode_uses_box_glyphs_test() {
  let out = error_presenter.render(sample_diagnostic(), off, True)
  string.contains(out, "╭─[") |> should.be_true
  string.contains(out, "╰─") |> should.be_true
  string.contains(out, "│") |> should.be_true
}

pub fn render_unicode_uses_heavy_underline_test() {
  let out = error_presenter.render(sample_diagnostic(), off, True)
  string.contains(out, "━") |> should.be_true
}

pub fn render_includes_label_after_underline_test() {
  let out = error_presenter.render(sample_diagnostic(), off, True)
  // The span has label "here" — it should appear next to the underline.
  string.contains(out, "here") |> should.be_true
}

// --- Snippet structure (ASCII fallback) ---

pub fn render_ascii_uses_caret_underline_test() {
  let out = error_presenter.render(sample_diagnostic(), off, False)
  string.contains(out, "^") |> should.be_true
  string.contains(out, "━") |> should.be_false
}

pub fn render_ascii_uses_ascii_box_test() {
  let out = error_presenter.render(sample_diagnostic(), off, False)
  string.contains(out, ",-[") |> should.be_true
  string.contains(out, "'-") |> should.be_true
  string.contains(out, "╭") |> should.be_false
  string.contains(out, "│") |> should.be_false
}

// --- Context window ---

pub fn render_shows_two_lines_above_test() {
  // Center line is 3; with context_above=2 we expect lines 1 and 2 in the output.
  let out = error_presenter.render(sample_diagnostic(), off, True)
  string.contains(out, "line 1") |> should.be_true
  string.contains(out, "line 2") |> should.be_true
}

pub fn render_shows_one_line_below_test() {
  let out = error_presenter.render(sample_diagnostic(), off, True)
  string.contains(out, "line 4") |> should.be_true
  // One line of context below means line 5 should NOT be there.
  string.contains(out, "line 5") |> should.be_false
}

pub fn render_shows_offending_line_test() {
  let out = error_presenter.render(sample_diagnostic(), off, True)
  string.contains(out, "line 3 BAD HERE") |> should.be_true
}

// --- Footers ---

pub fn render_includes_help_lines_test() {
  let out = error_presenter.render(sample_diagnostic(), off, True)
  string.contains(out, "= help:") |> should.be_true
  string.contains(out, "Did you mean 'foo'?") |> should.be_true
}

pub fn render_always_includes_explain_footer_test() {
  let out = error_presenter.render(sample_diagnostic(), off, True)
  string.contains(out, "caffeine explain E100") |> should.be_true
}

// --- No-snippet path: when source is missing, no box, but footer still there ---

pub fn render_without_source_skips_snippet_test() {
  let d =
    diagnostic.Diagnostic(
      ..sample_diagnostic(),
      source: None,
    )
  let out = error_presenter.render(d, off, True)
  // Box header still appears (we know the file/line) but no body or footer.
  string.contains(out, "╭─[") |> should.be_true
  string.contains(out, "line 3") |> should.be_false
  string.contains(out, "╰─") |> should.be_false
  // Explain footer still present.
  string.contains(out, "caffeine explain E100") |> should.be_true
}

// --- No-color invariant ---

pub fn render_color_off_has_no_escapes_test() {
  let out = error_presenter.render(sample_diagnostic(), off, True)
  string.contains(out, "\u{001b}[") |> should.be_false
}

// --- Severity coloring picks the right word ---

pub fn render_warning_uses_warning_word_test() {
  let d =
    diagnostic.Diagnostic(
      ..sample_diagnostic(),
      severity: diagnostic.Warning,
    )
  let out = error_presenter.render(d, off, True)
  string.contains(out, "warning[E100]") |> should.be_true
  string.contains(out, "error[E100]") |> should.be_false
}
