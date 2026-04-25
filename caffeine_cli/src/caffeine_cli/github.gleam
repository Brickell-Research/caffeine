/// Resolve the latest published Caffeine release tag from GitHub.
///
/// We shell out to `curl` rather than pulling in an HTTP client dep —
/// this is the same approach `cvm` uses for `cvm install latest`, and
/// the courtesy nature of the update check (silent on any failure) makes
/// the cost of a missing `curl` acceptable.
import gleam/list
import gleam/string
import shellout

const repo: String = "Brickell-Research/caffeine"

/// Returns the most recent release tag with any leading `v` stripped
/// (e.g. `5.1.1`). Errors out silently — the caller turns any failure
/// into "no notice shown" rather than surfacing it.
pub fn resolve_latest() -> Result(String, Nil) {
  let url = "https://api.github.com/repos/" <> repo <> "/releases/latest"
  case curl_get(url) {
    Ok(body) -> extract_tag(body)
    Error(_) -> Error(Nil)
  }
}

fn curl_get(url: String) -> Result(String, Nil) {
  case
    shellout.command(
      run: "curl",
      with: ["-sS", "--fail", "--max-time", "2", url],
      in: ".",
      opt: [],
    )
  {
    Ok(body) -> Ok(body)
    Error(_) -> Error(Nil)
  }
}

/// Find the first `"tag_name": "..."` value in a GitHub API response.
/// Hand-rolled splitter (no JSON dep) — same shape as `cvm/github`.
@internal
pub fn extract_tag(body: String) -> Result(String, Nil) {
  case
    body
    |> string.split("\"tag_name\"")
    |> list.drop(1)
    |> list.first
  {
    Ok(chunk) ->
      case string.split(chunk, "\"") {
        [_, tag, ..] -> Ok(strip_v(tag))
        _ -> Error(Nil)
      }
    Error(_) -> Error(Nil)
  }
}

fn strip_v(s: String) -> String {
  case s {
    "v" <> rest -> rest
    _ -> s
  }
}
