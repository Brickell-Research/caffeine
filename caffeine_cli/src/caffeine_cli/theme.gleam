/// Resolve the brand theme for a CLI run.
///
/// Brand verbs (Brewing/Served/Burnt) are on by default. The user can
/// opt out with `--no-theme` or `CAFFEINE_NO_THEME=<truthy>`. The flag
/// wins over the env var; the env var wins over the default.
import caffeine_cli/compile_presenter.{type Theme, Plain, Themed}
import envoy

/// Pick a `Theme` given the parsed `--no-theme` flag.
pub fn resolve(no_theme_flag: Bool) -> Theme {
  case no_theme_flag {
    True -> Plain
    False ->
      case env_truthy("CAFFEINE_NO_THEME") {
        True -> Plain
        False -> Themed
      }
  }
}

fn env_truthy(name: String) -> Bool {
  case envoy.get(name) {
    Ok(v) -> v != "" && v != "false" && v != "0"
    Error(_) -> False
  }
}
