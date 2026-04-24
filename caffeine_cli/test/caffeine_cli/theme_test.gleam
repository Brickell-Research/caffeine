import caffeine_cli/compile_presenter.{Plain, Themed}
import caffeine_cli/theme
import envoy
import gleeunit/should

fn clean() -> Nil {
  envoy.unset("CAFFEINE_NO_THEME")
}

pub fn flag_true_returns_plain_test() {
  clean()
  theme.resolve(True) |> should.equal(Plain)
}

pub fn flag_false_default_is_themed_test() {
  clean()
  theme.resolve(False) |> should.equal(Themed)
}

pub fn env_truthy_overrides_default_test() {
  clean()
  envoy.set("CAFFEINE_NO_THEME", "1")
  theme.resolve(False) |> should.equal(Plain)
  clean()
}

pub fn env_true_overrides_default_test() {
  clean()
  envoy.set("CAFFEINE_NO_THEME", "true")
  theme.resolve(False) |> should.equal(Plain)
  clean()
}

pub fn env_false_does_not_override_test() {
  clean()
  envoy.set("CAFFEINE_NO_THEME", "false")
  theme.resolve(False) |> should.equal(Themed)
  clean()
}

pub fn env_zero_does_not_override_test() {
  clean()
  envoy.set("CAFFEINE_NO_THEME", "0")
  theme.resolve(False) |> should.equal(Themed)
  clean()
}

pub fn env_empty_does_not_override_test() {
  clean()
  envoy.set("CAFFEINE_NO_THEME", "")
  theme.resolve(False) |> should.equal(Themed)
  clean()
}

pub fn flag_wins_over_env_test() {
  clean()
  envoy.set("CAFFEINE_NO_THEME", "0")
  // Even with env explicitly off, flag still forces Plain.
  theme.resolve(True) |> should.equal(Plain)
  clean()
}
