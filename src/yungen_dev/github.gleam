import gleam/dynamic/decode
import gleam/http/request
import gleam/httpc
import gleam/json
import gleam/list
import gleam/option.{type Option, None}
import gleam/regexp.{Match}
import gleam/result
import gleam/string

pub type Repo {
  Repo(full_name: String, description: String, language: String, stars: Int)
}

const user_agent = ""

// github.com paths whose first segment is a site route, not a user/org.
const reserved_owners = [
  "features", "pricing", "about", "login", "join", "marketplace", "explore",
  "topics", "trending", "collections", "events", "sponsors", "settings",
  "notifications", "new", "orgs", "apps", "contact", "security", "readme",
]

fn repo_regexp() -> regexp.Regexp {
  // github.com/<owner>/<repo>, each segment up to the next / # ?; any deeper path
  // (blob/tree/issues/...) is ignored — it still resolves to the owning repo.
  let assert Ok(re) =
    regexp.from_string("^https?://github\\.com/([^/#?\\s]+)/([^/#?\\s]+)")
  re
}

/// Owner + repo for a GitHub repo URL, or Error for non-repo / reserved-route
/// URLs (e.g. github.com/features/…, a bare profile, gist.github.com).
fn owner_repo(url: String) -> Result(#(String, String), Nil) {
  case regexp.scan(repo_regexp(), url) {
    [Match(_, [option.Some(owner), option.Some(repo)])] ->
      case list.contains(reserved_owners, string.lowercase(owner)) {
        True -> Error(Nil)
        False -> Ok(#(owner, strip_git_suffix(repo)))
      }
    _ -> Error(Nil)
  }
}

fn strip_git_suffix(repo: String) -> String {
  case string.ends_with(repo, ".git") {
    True -> string.drop_end(repo, 4)
    False -> repo
  }
}

/// True when `url` is a GitHub repository link we can annotate.
pub fn is_github_url(url: String) -> Bool {
  result.is_ok(owner_repo(url))
}

/// The REST API endpoint for a GitHub repo URL, e.g.
/// `https://github.com/traefik/traefik/blob/x` ->
/// `https://api.github.com/repos/traefik/traefik`.
pub fn api_url(url: String) -> Result(String, Nil) {
  use #(owner, repo) <- result.try(owner_repo(url))
  Ok("https://api.github.com/repos/" <> owner <> "/" <> repo)
}

/// Fetch + parse repository metadata for a GitHub repo URL. Any failure (non-repo
/// URL, network error, non-200, unparseable body) is `Error(Nil)`.
pub fn fetch(url: String) -> Result(Repo, Nil) {
  use api <- result.try(api_url(url))
  use req <- result.try(request.to(api) |> result.replace_error(Nil))
  let req =
    req
    |> request.set_header("user-agent", user_agent)
    |> request.set_header("accept", "application/vnd.github+json")
  use resp <- result.try(
    httpc.configure()
    |> httpc.follow_redirects(True)
    |> httpc.dispatch(req)
    |> result.replace_error(Nil),
  )
  case resp.status {
    200 -> json.parse(resp.body, repo_decoder()) |> result.replace_error(Nil)
    _ -> Error(Nil)
  }
}

fn repo_decoder() -> decode.Decoder(Repo) {
  // description and language are nullable in the API response.
  use full_name <- decode.field("full_name", decode.string)
  use description <- decode.optional_field(
    "description",
    None,
    decode.optional(decode.string),
  )
  use language <- decode.optional_field(
    "language",
    None,
    decode.optional(decode.string),
  )
  use stars <- decode.optional_field("stargazers_count", 0, decode.int)
  decode.success(Repo(
    full_name: full_name,
    description: nil_to_empty(description),
    language: nil_to_empty(language),
    stars: stars,
  ))
}

fn nil_to_empty(o: Option(String)) -> String {
  option.unwrap(o, "")
}
