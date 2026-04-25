import caffeine_cli/tty
import envoy
import gleeunit/should

// Env vars touched in these tests; reset before and after each case.
const env_vars = [
  "NO_COLOR", "FORCE_COLOR", "CLICOLOR", "CLICOLOR_FORCE", "CAFFEINE_COLOR",
  "TERM", "CI", "GITHUB_ACTIONS", "GITLAB_CI", "BUILDKITE", "CIRCLECI",
  "JENKINS_URL", "TF_BUILD",
]

fn clean() -> Nil {
  unset_each(env_vars)
}

fn unset_each(names: List(String)) -> Nil {
  case names {
    [] -> Nil
    [n, ..rest] -> {
      envoy.unset(n)
      unset_each(rest)
    }
  }
}

// --- ColorChoice precedence ---

pub fn always_overrides_no_color_test() {
  clean()
  envoy.set("NO_COLOR", "1")
  let caps = tty.detect(tty.Always)
  caps.color |> should.be_true
  clean()
}

pub fn never_overrides_force_color_test() {
  clean()
  envoy.set("FORCE_COLOR", "1")
  let caps = tty.detect(tty.Never)
  caps.color |> should.be_false
  clean()
}

pub fn always_does_not_force_dumb_terminal_test() {
  clean()
  envoy.set("TERM", "dumb")
  let caps = tty.detect(tty.Always)
  // Even Always cannot make a dumb terminal render escapes.
  caps.color |> should.be_false
  clean()
}

// --- NO_COLOR: must be non-empty per no-color.org ---

pub fn no_color_empty_does_not_disable_test() {
  clean()
  envoy.set("NO_COLOR", "")
  envoy.set("FORCE_COLOR", "1")
  // Empty NO_COLOR should NOT disable; FORCE_COLOR=1 should still take effect.
  let caps = tty.detect(tty.Auto)
  caps.color |> should.be_true
  clean()
}

pub fn no_color_non_empty_disables_test() {
  clean()
  envoy.set("NO_COLOR", "1")
  envoy.set("FORCE_COLOR", "1")
  let caps = tty.detect(tty.Auto)
  caps.color |> should.be_false
  clean()
}

pub fn no_color_any_value_disables_test() {
  clean()
  envoy.set("NO_COLOR", "anything-here")
  let caps = tty.detect(tty.Auto)
  caps.color |> should.be_false
  clean()
}

// --- FORCE_COLOR ---

pub fn force_color_1_enables_test() {
  clean()
  envoy.set("FORCE_COLOR", "1")
  let caps = tty.detect(tty.Auto)
  caps.color |> should.be_true
  clean()
}

pub fn force_color_0_disables_test() {
  clean()
  envoy.set("FORCE_COLOR", "0")
  let caps = tty.detect(tty.Auto)
  caps.color |> should.be_false
  clean()
}

pub fn force_color_false_disables_test() {
  clean()
  envoy.set("FORCE_COLOR", "false")
  let caps = tty.detect(tty.Auto)
  caps.color |> should.be_false
  clean()
}

// --- CAFFEINE_COLOR (project override) ---

pub fn caffeine_color_never_disables_test() {
  clean()
  envoy.set("CAFFEINE_COLOR", "never")
  envoy.set("FORCE_COLOR", "1")
  // Project override wins over FORCE_COLOR.
  let caps = tty.detect(tty.Auto)
  caps.color |> should.be_false
  clean()
}

pub fn caffeine_color_always_enables_test() {
  clean()
  envoy.set("CAFFEINE_COLOR", "always")
  envoy.set("NO_COLOR", "1")
  // Project override wins over NO_COLOR.
  let caps = tty.detect(tty.Auto)
  caps.color |> should.be_true
  clean()
}

// --- CI detection ---

pub fn ci_var_marks_ci_test() {
  clean()
  envoy.set("CI", "true")
  let caps = tty.detect(tty.Auto)
  caps.is_ci |> should.be_true
  clean()
}

pub fn ci_false_does_not_mark_ci_test() {
  clean()
  envoy.set("CI", "false")
  let caps = tty.detect(tty.Auto)
  caps.is_ci |> should.be_false
  clean()
}

pub fn github_actions_marks_ci_test() {
  clean()
  envoy.set("GITHUB_ACTIONS", "true")
  let caps = tty.detect(tty.Auto)
  caps.is_ci |> should.be_true
  caps.is_github_actions |> should.be_true
  clean()
}

// --- TERM=dumb disables Unicode ---

pub fn term_dumb_disables_unicode_test() {
  clean()
  envoy.set("TERM", "dumb")
  let caps = tty.detect(tty.Auto)
  caps.unicode |> should.be_false
  clean()
}
