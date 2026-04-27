import caffeine_cli/args
import caffeine_cli/color
import caffeine_cli/compile_presenter.{Plain, Themed}
import caffeine_cli/help
import gleam/option.{Some}
import gleam/string
import gleeunit/should

const off = color.ColorDisabled

const on = color.ColorEnabled

// --- Themed: structure ---

pub fn themed_includes_tagline_test() {
  let out = help.render(off, Themed, True)
  string.contains(out, "reliability artifacts, freshly compiled.")
  |> should.be_true
}

pub fn themed_lists_all_commands_test() {
  let out = help.render(off, Themed, True)
  ["compile", "format", "artifacts", "types"]
  |> all_present(out)
}

pub fn themed_lists_all_flags_test() {
  let out = help.render(off, Themed, True)
  ["--quiet", "--check", "--target=", "--no-theme", "-v, --version", "--help"]
  |> all_present(out)
}

pub fn themed_includes_docs_url_test() {
  let out = help.render(off, Themed, True)
  string.contains(out, "https://caffeine.brickellresearch.org")
  |> should.be_true
}

// --- Themed: Unicode vs ASCII fallback ---

pub fn themed_unicode_uses_box_drawing_test() {
  let out = help.render(off, Themed, True)
  string.contains(out, "╭") |> should.be_true
  string.contains(out, "╰") |> should.be_true
  string.contains(out, "│") |> should.be_true
  string.contains(out, "─") |> should.be_true
}

pub fn themed_no_unicode_uses_ascii_box_test() {
  let out = help.render(off, Themed, False)
  // No Unicode box-drawing.
  string.contains(out, "╭") |> should.be_false
  string.contains(out, "│") |> should.be_false
  // ASCII fallback present.
  string.contains(out, "+-") |> should.be_true
  string.contains(out, "|") |> should.be_true
}

// --- Themed: color on adds escapes, color off does not ---

pub fn themed_color_off_has_no_escapes_test() {
  let out = help.render(off, Themed, True)
  string.contains(out, "\u{001b}[") |> should.be_false
}

pub fn themed_color_on_has_escapes_test() {
  let out = help.render(on, Themed, True)
  string.contains(out, "\u{001b}[") |> should.be_true
}

// --- Plain (--no-theme) ---

pub fn plain_uses_legacy_layout_test() {
  let out = help.render(off, Plain, True)
  // Plain mode keeps the old USAGE: / COMMANDS: / FLAGS: shape.
  string.contains(out, "USAGE:") |> should.be_true
  string.contains(out, "COMMANDS:") |> should.be_true
  string.contains(out, "FLAGS:") |> should.be_true
}

pub fn plain_does_not_use_box_drawing_test() {
  let out = help.render(off, Plain, True)
  string.contains(out, "╭") |> should.be_false
  string.contains(out, "│") |> should.be_false
}

pub fn plain_does_not_use_themed_tagline_test() {
  let out = help.render(off, Plain, True)
  string.contains(out, "freshly compiled") |> should.be_false
}

pub fn plain_lists_all_commands_test() {
  let out = help.render(off, Plain, True)
  ["compile", "format", "artifacts", "types"]
  |> all_present(out)
}

// --- Per-command help (`caffeine help <cmd>` / `caffeine <cmd> --help`) ---

pub fn render_command_includes_name_and_summary_test() {
  let assert Some(spec) = args.find("compile")
  let out = help.render_command(spec, off)
  string.contains(out, "caffeine compile") |> should.be_true
  string.contains(out, spec.summary) |> should.be_true
}

pub fn render_command_shows_usage_signature_test() {
  let assert Some(spec) = args.find("compile")
  let out = help.render_command(spec, off)
  string.contains(out, "Usage:") |> should.be_true
  string.contains(out, "<measurements_dir>") |> should.be_true
  string.contains(out, "[output_path]") |> should.be_true
}

pub fn render_command_shows_description_test() {
  let assert Some(spec) = args.find("format")
  let out = help.render_command(spec, off)
  // Non-trivial substring of format's description.
  string.contains(out, "non-zero") |> should.be_true
}

pub fn render_command_shows_flags_when_present_test() {
  let assert Some(spec) = args.find("compile")
  let out = help.render_command(spec, off)
  string.contains(out, "Flags:") |> should.be_true
  string.contains(out, "--target") |> should.be_true
  string.contains(out, "--quiet") |> should.be_true
}

pub fn render_command_omits_flags_section_when_none_test() {
  let assert Some(spec) = args.find("explain")
  let out = help.render_command(spec, off)
  // explain has no per-command flags.
  string.contains(out, "Flags:") |> should.be_false
}

pub fn render_command_shows_examples_test() {
  let assert Some(spec) = args.find("compile")
  let out = help.render_command(spec, off)
  string.contains(out, "Examples:") |> should.be_true
  string.contains(out, "caffeine compile measurements/ expectations/")
  |> should.be_true
}

pub fn render_command_color_off_has_no_escapes_test() {
  let assert Some(spec) = args.find("compile")
  let out = help.render_command(spec, off)
  string.contains(out, "\u{001b}[") |> should.be_false
}

// --- Helpers ---

fn all_present(items: List(String), text: String) -> Nil {
  case items {
    [] -> Nil
    [item, ..rest] -> {
      case string.contains(text, item) {
        True -> all_present(rest, text)
        False ->
          panic as {
            "expected '" <> item <> "' in help output, but it was missing"
          }
      }
    }
  }
}
