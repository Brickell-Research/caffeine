/// Monotonic wall-clock timestamps in milliseconds.
///
/// Used by the compile presenter to show elapsed time. Monotonic on
/// Erlang via `erlang:monotonic_time/1`; on JS we fall back to
/// `Date.now()` since `performance.now()` isn't always available in
/// non-browser runtimes.
import gleam/int

@external(erlang, "caffeine_cli_clock_ffi", "now_ms")
@external(javascript, "../caffeine_cli_ffi.mjs", "now_ms")
pub fn now_ms() -> Int

/// Format an elapsed millisecond count for human display.
/// Sub-second values render as "Xms"; >= 1s renders as "X.YYs".
pub fn format_elapsed(ms: Int) -> String {
  case ms < 1000 {
    True -> int.to_string(ms) <> "ms"
    False -> {
      let whole = ms / 1000
      let hundredths = { ms - whole * 1000 } / 10
      int.to_string(whole) <> "." <> pad2(hundredths) <> "s"
    }
  }
}

fn pad2(n: Int) -> String {
  case n < 10 {
    True -> "0" <> int.to_string(n)
    False -> int.to_string(n)
  }
}
