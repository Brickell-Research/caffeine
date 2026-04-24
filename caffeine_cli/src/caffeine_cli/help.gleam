/// Renderer for `caffeine --help`.
///
/// Two presentations:
///   - Themed (default): tagline + box-drawn commands list + amber verbs.
///   - Plain (`--no-theme`): cargo-style flat sections in default text.
///
/// Both degrade gracefully when the terminal is not Unicode-capable
/// (box switches to ASCII `+ - |`) and when color is off (no escapes).
import caffeine_cli/color.{type ColorMode}
import caffeine_cli/compile_presenter.{type Theme, Plain, Themed}
import caffeine_lang/constants
import gleam/int
import gleam/list
import gleam/regexp
import gleam/string

/// One row in the COMMANDS section.
type Command {
  Command(name: String, description: String)
}

/// One row in the FLAGS section.
type Flag {
  Flag(name: String, description: String)
}

const tagline: String = "reliability artifacts, freshly compiled."

const docs_url: String = "https://caffeine.brickellresearch.org"

const box_inner_width: Int = 72

fn commands() -> List(Command) {
  [
    Command("compile", "Compile measurements + expectations to a target"),
    Command("validate", "Type-check without writing output"),
    Command("format", "Format .caffeine files"),
    Command("artifacts", "List standard-library artifacts"),
    Command("types", "Show the type-system reference"),
    Command("lsp", "Start the language server (used by editors)"),
  ]
}

fn flags() -> List(Flag) {
  [
    Flag("--quiet", "Suppress compilation progress output"),
    Flag("--check", "Check formatting without modifying files (format only)"),
    Flag("--target=<terraform|opentofu>", "Codegen target (default: terraform)"),
    Flag("--no-theme", "Use neutral status verbs (also via CAFFEINE_NO_THEME=1)"),
    Flag("-v, --version", "Show version information"),
    Flag("--help", "Show this help message"),
  ]
}

/// Render the top-level `caffeine --help` for the given capabilities.
pub fn render(color_mode: ColorMode, theme: Theme, unicode: Bool) -> String {
  case theme {
    Themed -> render_themed(color_mode, unicode)
    Plain -> render_plain(color_mode)
  }
}

// --- Themed presentation ---

fn render_themed(color_mode: ColorMode, unicode: Bool) -> String {
  let banner =
    color.bold(color.amber("caffeine", color_mode), color_mode)
    <> " "
    <> constants.version
    <> color.dim(" — " <> tagline, color_mode)

  let usage =
    color.bold(color.cyan("Usage:", color_mode), color_mode)
    <> "  caffeine <command> [flags] [arguments]"

  let cmd_box = render_box("commands", commands_to_lines(color_mode), unicode, color_mode)

  let flag_lines =
    flags()
    |> list.map(format_flag_line(_, color_mode))
    |> string.join("\n")
  let flags_section =
    color.bold(color.cyan("Flags:", color_mode), color_mode) <> "\n" <> flag_lines

  let docs =
    color.bold(color.cyan("Docs:", color_mode), color_mode)
    <> "   "
    <> color.dim(docs_url, color_mode)

  string.join([banner, "", usage, "", cmd_box, "", flags_section, "", docs], "\n")
}

fn commands_to_lines(color_mode: ColorMode) -> List(String) {
  let cmds = commands()
  let name_width =
    list.fold(cmds, 0, fn(acc, c) { int.max(acc, string.length(c.name)) })
  list.map(cmds, fn(c) {
    let pad = string.repeat(" ", name_width - string.length(c.name))
    color.bold(color.amber(c.name, color_mode), color_mode)
    <> pad
    <> "  "
    <> color.dim(c.description, color_mode)
  })
}

fn format_flag_line(flag: Flag, color_mode: ColorMode) -> String {
  let pad = case 30 - string.length(flag.name) {
    n if n > 0 -> string.repeat(" ", n)
    _ -> "  "
  }
  "  "
  <> color.cyan(flag.name, color_mode)
  <> pad
  <> color.dim(flag.description, color_mode)
}

// --- Plain presentation (--no-theme) ---

fn render_plain(color_mode: ColorMode) -> String {
  // Mirrors the pre-themed help so users who opt out get the familiar shape.
  let cmds = commands()
  let cmd_name_width =
    list.fold(cmds, 0, fn(acc, c) { int.max(acc, string.length(c.name)) })
  let cmd_lines =
    cmds
    |> list.map(fn(c) {
      let pad = string.repeat(" ", cmd_name_width - string.length(c.name))
      "  " <> color.bold(c.name, color_mode) <> pad <> "  " <> c.description
    })
    |> string.join("\n")

  let fls = flags()
  let flag_name_width =
    list.fold(fls, 0, fn(acc, f) { int.max(acc, string.length(f.name)) })
  let flag_lines =
    fls
    |> list.map(fn(f) {
      let pad = string.repeat(" ", flag_name_width - string.length(f.name))
      "  " <> f.name <> pad <> "  " <> f.description
    })
    |> string.join("\n")

  string.join(
    [
      "caffeine - A compiler for generating reliability artifacts from service expectation definitions.",
      "",
      "Version: " <> constants.version,
      "",
      "USAGE:",
      "  caffeine <command> [flags] [arguments]",
      "",
      "COMMANDS:",
      cmd_lines,
      "",
      "FLAGS:",
      flag_lines,
    ],
    "\n",
  )
}

// --- Box drawing ---

fn render_box(
  title: String,
  lines: List(String),
  unicode: Bool,
  color_mode: ColorMode,
) -> String {
  let glyphs = case unicode {
    True -> BoxGlyphs(tl: "╭", tr: "╮", bl: "╰", br: "╯", h: "─", v: "│")
    False -> BoxGlyphs(tl: "+", tr: "+", bl: "+", br: "+", h: "-", v: "|")
  }

  let title_segment = " " <> title <> " "
  let title_len = string.length(title_segment)
  let after_title = box_inner_width - title_len - 1
  let after_title = int.max(0, after_title)
  let top =
    color.dim(
      glyphs.tl
        <> glyphs.h
        <> title_segment
        <> string.repeat(glyphs.h, after_title)
        <> glyphs.tr,
      color_mode,
    )

  let body =
    lines
    |> list.map(fn(line) { wrap_in_box(line, glyphs.v, color_mode) })
    |> string.join("\n")

  let bottom =
    color.dim(
      glyphs.bl <> string.repeat(glyphs.h, box_inner_width) <> glyphs.br,
      color_mode,
    )

  string.join([top, body, bottom], "\n")
}

type BoxGlyphs {
  BoxGlyphs(
    tl: String,
    tr: String,
    bl: String,
    br: String,
    h: String,
    v: String,
  )
}

/// Wrap a styled body line in box pipes, padding with spaces inside the
/// frame. `visible_length` strips ANSI escapes so colored content still
/// aligns to `box_inner_width`.
fn wrap_in_box(line: String, pipe: String, color_mode: ColorMode) -> String {
  let visible = visible_length(line)
  let inner_target = box_inner_width - 2
  let pad = int.max(0, inner_target - visible)
  color.dim(pipe, color_mode)
  <> "  "
  <> line
  <> string.repeat(" ", pad)
  <> color.dim(pipe, color_mode)
}

/// Approximate visible length by stripping ANSI CSI escape sequences.
fn visible_length(s: String) -> Int {
  string.length(strip_ansi(s))
}

fn strip_ansi(s: String) -> String {
  case regexp.from_string("\u{001b}\\[[0-9;]*[a-zA-Z]") {
    Ok(re) -> regexp.replace(each: re, in: s, with: "")
    Error(_) -> s
  }
}
