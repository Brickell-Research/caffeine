import caffeine_cli/clock
import gleeunit/should

pub fn now_ms_is_monotonic_test() {
  let a = clock.now_ms()
  let b = clock.now_ms()
  // Wall-clock advances forward; equal is acceptable for back-to-back calls.
  { b >= a } |> should.be_true
}

pub fn format_elapsed_under_a_second_test() {
  clock.format_elapsed(0) |> should.equal("0ms")
  clock.format_elapsed(1) |> should.equal("1ms")
  clock.format_elapsed(142) |> should.equal("142ms")
  clock.format_elapsed(999) |> should.equal("999ms")
}

pub fn format_elapsed_seconds_test() {
  clock.format_elapsed(1000) |> should.equal("1.00s")
  clock.format_elapsed(1234) |> should.equal("1.23s")
  clock.format_elapsed(4830) |> should.equal("4.83s")
  clock.format_elapsed(60_000) |> should.equal("60.00s")
}

pub fn format_elapsed_pads_hundredths_test() {
  // 1050ms -> 1 second and 5 hundredths -> "1.05s" (not "1.5s")
  clock.format_elapsed(1050) |> should.equal("1.05s")
  clock.format_elapsed(1005) |> should.equal("1.00s")
}
