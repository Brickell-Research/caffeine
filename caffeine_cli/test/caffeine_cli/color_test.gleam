import caffeine_cli/color
import envoy
import gleam/string
import gleeunit/should

fn clean() -> Nil {
  envoy.unset("NO_COLOR")
  envoy.unset("FORCE_COLOR")
  envoy.unset("CLICOLOR")
  envoy.unset("CLICOLOR_FORCE")
  envoy.unset("CAFFEINE_COLOR")
  envoy.unset("TERM")
}

// --- detect_color_mode honors NO_COLOR per spec ---

pub fn detect_color_mode_no_color_empty_test() {
  clean()
  envoy.set("NO_COLOR", "")
  envoy.set("FORCE_COLOR", "1")
  // Empty NO_COLOR is a no-op per no-color.org spec.
  case color.detect_color_mode() {
    color.ColorEnabled -> Nil
    color.ColorDisabled -> panic as "expected ColorEnabled with empty NO_COLOR"
  }
  clean()
}

pub fn detect_color_mode_no_color_set_test() {
  clean()
  envoy.set("NO_COLOR", "1")
  case color.detect_color_mode() {
    color.ColorDisabled -> Nil
    color.ColorEnabled -> panic as "expected ColorDisabled with NO_COLOR=1"
  }
  clean()
}

// --- Wrappers respect ColorMode ---

pub fn red_enabled_adds_escape_test() {
  let out = color.red("hello", color.ColorEnabled)
  // ANSI escape begins with \e (0x1B) — anything other than the literal
  // payload means styling was applied.
  { string.length(out) > string.length("hello") } |> should.be_true
  string.contains(out, "hello") |> should.be_true
}

pub fn red_disabled_passes_through_test() {
  let out = color.red("hello", color.ColorDisabled)
  out |> should.equal("hello")
}

pub fn yellow_disabled_passes_through_test() {
  let out = color.yellow("warn", color.ColorDisabled)
  out |> should.equal("warn")
}

pub fn magenta_disabled_passes_through_test() {
  let out = color.magenta("required", color.ColorDisabled)
  out |> should.equal("required")
}

pub fn amber_disabled_passes_through_test() {
  let out = color.amber("Brewing", color.ColorDisabled)
  out |> should.equal("Brewing")
}

pub fn amber_enabled_includes_payload_test() {
  let out = color.amber("Brewing", color.ColorEnabled)
  string.contains(out, "Brewing") |> should.be_true
  { string.length(out) > string.length("Brewing") } |> should.be_true
}

pub fn bold_disabled_passes_through_test() {
  let out = color.bold("loud", color.ColorDisabled)
  out |> should.equal("loud")
}

pub fn dim_disabled_passes_through_test() {
  let out = color.dim("quiet", color.ColorDisabled)
  out |> should.equal("quiet")
}
