/// ANSI styling wrappers gated by a `ColorMode`.
///
/// Color mode is derived from `tty.detect/1` so the no-color.org spec,
/// FORCE_COLOR, CLICOLOR(_FORCE), TERM=dumb, and isatty are all honored.
/// Callers should pass the returned `ColorMode` through to every styling
/// site rather than calling `gleam_community/ansi` directly.
import caffeine_cli/tty
import gleam_community/ansi

pub type ColorMode {
  ColorEnabled
  ColorDisabled
}

/// Detect color mode from the environment using default (Auto) preference.
pub fn detect_color_mode() -> ColorMode {
  from_capabilities(tty.detect(tty.Auto))
}

/// Detect color mode honoring an explicit caller preference (typically
/// from a --color flag).
pub fn detect_color_mode_with(choice: tty.ColorChoice) -> ColorMode {
  from_capabilities(tty.detect(choice))
}

/// Derive a ColorMode from already-detected capabilities. Useful when the
/// caller has already paid the cost of `tty.detect/1` for other capabilities.
pub fn from_capabilities(caps: tty.Capabilities) -> ColorMode {
  case caps.color {
    True -> ColorEnabled
    False -> ColorDisabled
  }
}

// --- Wrappers ---

pub fn red(text: String, mode: ColorMode) -> String {
  apply(text, mode, ansi.red)
}

pub fn green(text: String, mode: ColorMode) -> String {
  apply(text, mode, ansi.green)
}

pub fn yellow(text: String, mode: ColorMode) -> String {
  apply(text, mode, ansi.yellow)
}

pub fn blue(text: String, mode: ColorMode) -> String {
  apply(text, mode, ansi.blue)
}

pub fn cyan(text: String, mode: ColorMode) -> String {
  apply(text, mode, ansi.cyan)
}

pub fn magenta(text: String, mode: ColorMode) -> String {
  apply(text, mode, ansi.magenta)
}

/// Brand amber. Bright orange-yellow, deliberately distinct from `yellow`
/// (which is reserved for warnings) so the two never collide visually.
/// Used for branded progress verbs (Brewing, Pouring, Served, etc.).
pub fn amber(text: String, mode: ColorMode) -> String {
  apply(text, mode, fn(t) { ansi.hex(t, amber_hex) })
}

/// Brand amber as a 24-bit RGB integer. Exposed so callers writing tests
/// or alternate renderers can reference the same value.
pub const amber_hex: Int = 0xC9_7B_3F

/// Brand pink. Matches the star in the Brickell Research logo.
pub fn pink(text: String, mode: ColorMode) -> String {
  apply(text, mode, fn(t) { ansi.hex(t, pink_hex) })
}

pub const pink_hex: Int = 0xE5_7B_B8

pub fn bold(text: String, mode: ColorMode) -> String {
  apply(text, mode, ansi.bold)
}

pub fn dim(text: String, mode: ColorMode) -> String {
  apply(text, mode, ansi.dim)
}

fn apply(text: String, mode: ColorMode, style: fn(String) -> String) -> String {
  case mode {
    ColorEnabled -> style(text)
    ColorDisabled -> text
  }
}
