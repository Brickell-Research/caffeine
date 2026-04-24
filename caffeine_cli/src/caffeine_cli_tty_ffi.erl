%% Erlang FFI for terminal capability detection.
%%
%% `io:columns/0` returns `{ok, Cols}` when stdout is a terminal that
%% reports its width, and `{error, enotsup}` when it's redirected to a
%% pipe or file. We use that as the isatty signal — it's the most
%% portable indicator available without an Erlang NIF.
-module(caffeine_cli_tty_ffi).

-export([is_stdout_tty/0, stdout_columns/0]).

is_stdout_tty() ->
    case io:columns() of
        {ok, _} -> true;
        _ -> false
    end.

stdout_columns() ->
    case io:columns() of
        {ok, Cols} -> Cols;
        _ -> 80
    end.
