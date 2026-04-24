%% Erlang FFI for monotonic millisecond timestamps.
-module(caffeine_cli_clock_ffi).

-export([now_ms/0]).

now_ms() ->
    erlang:monotonic_time(millisecond).
