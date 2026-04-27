/// Renderer for `caffeine --help` and `caffeine help <command>`.
///
/// Two presentations:
///   - Themed (default): tagline + box-drawn commands list + amber verbs.
///   - Plain (`--no-theme`): cargo-style flat sections in default text.
///
/// Both degrade gracefully when the terminal is not Unicode-capable
/// (box switches to ASCII `+ - |`) and when color is off (no escapes).
///
/// Command definitions live in `args.gleam`; this module only renders.
import caffeine_cli/args.{type CommandSpec}
import caffeine_cli/color.{type ColorMode}
import caffeine_cli/compile_presenter.{type Theme, Plain, Themed}
import caffeine_lang/constants
import gleam/int
import gleam/list
import gleam/regexp
import gleam/string

/// One row in the global FLAGS section.
type Flag {
  Flag(name: String, description: String)
}

const tagline: String = "Systems thinking, without the thinking."

const docs_url: String = "https://brickellresearch.org"

const box_inner_width: Int = 72

fn flags() -> List(Flag) {
  [
    Flag("--quiet", "Suppress compilation progress output"),
    Flag("--check", "Check formatting without modifying files (format only)"),
    Flag("--target=<terraform|opentofu>", "Codegen target (default: terraform)"),
    Flag(
      "--no-theme",
      "Use neutral status verbs (also via CAFFEINE_NO_THEME=1)",
    ),
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
  let banner = render_banner(unicode, color_mode)

  let usage =
    color.bold(color.cyan("Usage:", color_mode), color_mode)
    <> "  caffeine <command> [flags] [arguments]"

  let cmd_box =
    render_box("commands", commands_to_lines(color_mode), unicode, color_mode)

  let flag_lines =
    flags()
    |> list.map(format_flag_line(_, color_mode))
    |> string.join("\n")
  let flags_section =
    color.bold(color.cyan("Flags:", color_mode), color_mode)
    <> "\n"
    <> flag_lines

  string.join([banner, "", usage, "", cmd_box, "", flags_section], "\n")
}

/// Compact 3-line banner: a pixel-block coffee mug on the left, a
/// vertically-stacked text block on the right (wordmark+version, tagline,
/// docs URL). Inspired by the Claude Code CLI's logo-plus-info banner.
/// Falls back to a plain wordmark line in non-Unicode terminals.
fn render_banner(unicode: Bool, color_mode: ColorMode) -> String {
  let pink = fn(s) { color.pink(s, color_mode) }
  let c_mark = color.bold(color.amber("C", color_mode), color_mode)
  let wordmark =
    color.bold(color.amber("caffeine", color_mode), color_mode)
    <> " "
    <> constants.version
  let slogan = color.dim(tagline, color_mode)
  let docs = color.dim(docs_url, color_mode)

  let dim = fn(s) { color.dim(s, color_mode) }
  case unicode {
    True ->
      string.join(
        [
          dim("   ~"),
          dim("  ~ ~"),
          pink(" ▄▄▄▄▄"),
          pink(" █   █╮") <> "    " <> wordmark,
          pink(" █ ") <> c_mark <> pink(" █│") <> "    " <> slogan,
          pink(" █   █╯") <> "    " <> docs,
          pink(" ▀▀▀▀▀"),
        ],
        "\n",
      )
    False ->
      // ASCII fallback: pixel-block art doesn't degrade gracefully, so
      // skip the mug and just show the text on its own.
      string.join([wordmark, slogan, docs], "\n")
  }
}

fn commands_to_lines(color_mode: ColorMode) -> List(String) {
  let cmds = args.commands()
  let name_width =
    list.fold(cmds, 0, fn(acc, c) { int.max(acc, string.length(c.name)) })
  list.map(cmds, fn(c) {
    let pad = string.repeat(" ", name_width - string.length(c.name))
    color.bold(color.amber(c.name, color_mode), color_mode)
    <> pad
    <> "  "
    <> color.dim(c.summary, color_mode)
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
  let cmds = args.commands()
  let cmd_name_width =
    list.fold(cmds, 0, fn(acc, c) { int.max(acc, string.length(c.name)) })
  let cmd_lines =
    cmds
    |> list.map(fn(c) {
      let pad = string.repeat(" ", cmd_name_width - string.length(c.name))
      "  " <> color.bold(c.name, color_mode) <> pad <> "  " <> c.summary
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

// --- Per-command help (`caffeine help <cmd>` / `caffeine <cmd> --help`) ---

/// Render help for a single subcommand. Layout:
///
///     caffeine compile — Compile measurements + expectations to a target
///
///     Usage:
///       caffeine compile <measurements_dir> <expectations_dir> [output_path]
///
///     <description>
///
///     Flags:
///       --target=<...>   Codegen target ...
///       --quiet          Suppress ...
///
///     Examples:
///       caffeine compile measurements/ expectations/
pub fn render_command(spec: CommandSpec, color_mode: ColorMode) -> String {
  let header =
    color.bold(color.amber("caffeine " <> spec.name, color_mode), color_mode)
    <> color.dim(" — " <> spec.summary, color_mode)

  let invocation = drop_usage_prefix(args.usage_message(spec))
  let usage =
    color.bold(color.cyan("Usage:", color_mode), color_mode)
    <> "\n  "
    <> invocation

  let description = spec.description

  let flags_section = case spec.flags {
    [] -> ""
    flag_specs -> {
      let lines =
        flag_specs
        |> list.map(format_per_command_flag(_, color_mode))
        |> string.join("\n")
      "\n\n"
      <> color.bold(color.cyan("Flags:", color_mode), color_mode)
      <> "\n"
      <> lines
    }
  }

  let examples_section = case spec.examples {
    [] -> ""
    examples ->
      "\n\n"
      <> color.bold(color.cyan("Examples:", color_mode), color_mode)
      <> "\n"
      <> {
        examples
        |> list.map(fn(e) { "  " <> color.dim(e, color_mode) })
        |> string.join("\n")
      }
  }

  string.join(
    [header, "", usage, "", description <> flags_section <> examples_section],
    "\n",
  )
}

/// Format one flag row for per-command help (slightly tighter than the
/// global FLAGS section: 28-col gutter rather than 30).
fn format_per_command_flag(
  flag: args.FlagSpec,
  color_mode: ColorMode,
) -> String {
  let pad = case 28 - string.length(flag.name) {
    n if n > 0 -> string.repeat(" ", n)
    _ -> "  "
  }
  "  "
  <> color.cyan(flag.name, color_mode)
  <> pad
  <> color.dim(flag.description, color_mode)
}

/// `args.usage_message` returns "Usage: caffeine compile <args>". The
/// per-command help already shows "Usage:" as a section heading, so we
/// strip the leading "Usage: " and indent the bare invocation line.
fn drop_usage_prefix(s: String) -> String {
  case string.split_once(s, "Usage: ") {
    Ok(#(_, rest)) -> rest
    Error(_) -> s
  }
}
