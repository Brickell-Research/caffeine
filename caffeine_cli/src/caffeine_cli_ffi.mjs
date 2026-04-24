// JS equivalent for erlang's halt/1. See: https://www.erlang.org/doc/apps/erts/erlang.html#halt/1
export function halt(code) {
  process.exit(code);
}

// Terminal capability FFI used by caffeine_cli/tty.gleam.
export function is_stdout_tty() {
  return Boolean(process.stdout && process.stdout.isTTY);
}

export function stdout_columns() {
  return (process.stdout && process.stdout.columns) || 80;
}

export function now_ms() {
  return Date.now();
}
