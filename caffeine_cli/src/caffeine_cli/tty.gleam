/// Terminal capability detection.
///
/// Resolves color support, Unicode support, TTY status, CI detection, and
/// terminal width from the environment, following the de-facto precedence:
///
///   1. explicit ColorChoice (typically from a --color flag)
///   2. CAFFEINE_COLOR env var
///   3. NO_COLOR (per https://no-color.org — must be a non-empty string)
///   4. FORCE_COLOR={1,2,3,true} or {0,false}
///   5. CLICOLOR_FORCE non-zero / CLICOLOR=0
///   6. TERM=dumb (disables color and Unicode)
///   7. isatty(stdout)
///   8. otherwise enabled
///
/// Spinners and progress are gated on `is_tty AND NOT is_ci`. Color is
/// independently gated; CI runners render ANSI fine and color helps log scanning.
import envoy
import gleam/list
import gleam/string

/// Caller's color preference. `Auto` defers entirely to env detection.
pub type ColorChoice {
  Auto
  Always
  Never
}

/// Detected terminal capabilities.
pub type Capabilities {
  Capabilities(
    color: Bool,
    unicode: Bool,
    is_tty: Bool,
    is_ci: Bool,
    is_github_actions: Bool,
    width: Int,
  )
}

/// Detect capabilities from the current environment.
pub fn detect(choice: ColorChoice) -> Capabilities {
  let tty = is_stdout_tty()
  let term_dumb = case envoy.get("TERM") {
    Ok("dumb") -> True
    _ -> False
  }

  Capabilities(
    color: resolve_color(choice, tty, term_dumb),
    unicode: resolve_unicode(term_dumb),
    is_tty: tty,
    is_ci: is_ci(),
    is_github_actions: env_truthy("GITHUB_ACTIONS"),
    width: stdout_columns(),
  )
}

// --- Color resolution ---

fn resolve_color(choice: ColorChoice, is_tty: Bool, term_dumb: Bool) -> Bool {
  case choice {
    Always -> !term_dumb
    Never -> False
    Auto -> resolve_color_auto(is_tty, term_dumb)
  }
}

fn resolve_color_auto(is_tty: Bool, term_dumb: Bool) -> Bool {
  case envoy.get("CAFFEINE_COLOR") {
    Ok(v) ->
      case string.lowercase(v) {
        "always" -> !term_dumb
        "never" -> False
        _ -> resolve_color_env(is_tty, term_dumb)
      }
    Error(_) -> resolve_color_env(is_tty, term_dumb)
  }
}

/// Apply NO_COLOR / FORCE_COLOR / CLICOLOR(_FORCE) / TERM=dumb / isatty in order.
fn resolve_color_env(is_tty: Bool, term_dumb: Bool) -> Bool {
  // no-color.org: present AND non-empty disables color.
  case envoy.get("NO_COLOR") {
    Ok(v) if v != "" -> False
    _ ->
      case envoy.get("FORCE_COLOR") {
        Ok(v) -> force_color_to_bool(v, term_dumb)
        Error(_) -> resolve_clicolor(is_tty, term_dumb)
      }
  }
}

fn force_color_to_bool(value: String, term_dumb: Bool) -> Bool {
  case string.lowercase(value), term_dumb {
    _, True -> False
    "0", _ | "false", _ -> False
    _, _ -> True
  }
}

fn resolve_clicolor(is_tty: Bool, term_dumb: Bool) -> Bool {
  case envoy.get("CLICOLOR_FORCE") {
    Ok(v) if v != "" && v != "0" -> !term_dumb
    _ ->
      case envoy.get("CLICOLOR") {
        Ok("0") -> False
        _ ->
          case term_dumb {
            True -> False
            False -> is_tty
          }
      }
  }
}

// --- Unicode resolution ---

fn resolve_unicode(term_dumb: Bool) -> Bool {
  case term_dumb {
    True -> False
    False -> locale_is_utf8()
  }
}

fn locale_is_utf8() -> Bool {
  case first_set_env(["LC_ALL", "LC_CTYPE", "LANG"]) {
    Ok(v) -> {
      let lower = string.lowercase(v)
      string.contains(lower, "utf-8") || string.contains(lower, "utf8")
    }
    // No locale set: assume UTF-8 on modern systems.
    Error(_) -> True
  }
}

// --- CI detection ---

fn is_ci() -> Bool {
  [
    "CI", "GITHUB_ACTIONS", "GITLAB_CI", "BUILDKITE", "CIRCLECI", "JENKINS_URL",
    "TF_BUILD",
  ]
  |> list.any(env_truthy)
}

// --- Helpers ---

fn env_truthy(name: String) -> Bool {
  case envoy.get(name) {
    Ok(v) -> v != "" && v != "false" && v != "0"
    Error(_) -> False
  }
}

fn first_set_env(names: List(String)) -> Result(String, Nil) {
  case names {
    [] -> Error(Nil)
    [name, ..rest] ->
      case envoy.get(name) {
        Ok(v) if v != "" -> Ok(v)
        _ -> first_set_env(rest)
      }
  }
}

// --- TTY / width FFI ---

@external(erlang, "caffeine_cli_tty_ffi", "is_stdout_tty")
@external(javascript, "../caffeine_cli_ffi.mjs", "is_stdout_tty")
fn is_stdout_tty() -> Bool

@external(erlang, "caffeine_cli_tty_ffi", "stdout_columns")
@external(javascript, "../caffeine_cli_ffi.mjs", "stdout_columns")
fn stdout_columns() -> Int
