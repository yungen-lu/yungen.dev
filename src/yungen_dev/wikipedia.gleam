import gleam/dynamic/decode
import gleam/http/request
import gleam/httpc
import gleam/json
import gleam/option.{Some}
import gleam/regexp.{Match}
import gleam/result
import gleam/string

pub type Summary {
  Summary(title: String, description: String, extract: String)
}

const user_agent = ""

fn article_regexp() -> regexp.Regexp {
  // <lang>[.m].wikipedia.org/wiki/<title>, title up to a #fragment or ?query.
  let assert Ok(re) =
    regexp.from_string(
      "^https?://([a-z-]+)(?:\\.m)?\\.wikipedia\\.org/wiki/([^#?\\s]+)",
    )
  re
}

/// True when `url` is a Wikipedia article link we can annotate.
pub fn is_wikipedia_url(url: String) -> Bool {
  regexp.check(article_regexp(), url)
}

/// The REST summary endpoint for a Wikipedia article URL, e.g.
/// `https://en.wikipedia.org/wiki/Kubernetes` ->
/// `https://en.wikipedia.org/api/rest_v1/page/summary/Kubernetes`. The article
/// title keeps its original percent-encoding, and the desktop host is always
/// used (any `.m` mobile subdomain is dropped).
pub fn summary_url(article_url: String) -> Result(String, Nil) {
  case regexp.scan(article_regexp(), article_url) {
    [Match(_, [Some(lang), Some(title)])] ->
      Ok(
        "https://"
        <> lang
        <> ".wikipedia.org/api/rest_v1/page/summary/"
        <> title,
      )
    _ -> Error(Nil)
  }
}

/// Fetch + parse the summary for a Wikipedia article URL. Any failure (non-WP
/// URL, network error, non-200, unparseable body, empty extract) is `Error(Nil)`.
pub fn fetch(article_url: String) -> Result(Summary, Nil) {
  use api <- result.try(summary_url(article_url))
  use req <- result.try(request.to(api) |> result.replace_error(Nil))
  let req = request.set_header(req, "user-agent", user_agent)
  use resp <- result.try(
    httpc.configure()
    |> httpc.follow_redirects(True)
    |> httpc.dispatch(req)
    |> result.replace_error(Nil),
  )
  case resp.status {
    200 -> {
      use summary <- result.try(
        json.parse(resp.body, summary_decoder()) |> result.replace_error(Nil),
      )
      case string.trim(summary.extract) {
        "" -> Error(Nil)
        _ -> Ok(summary)
      }
    }
    _ -> Error(Nil)
  }
}

fn summary_decoder() -> decode.Decoder(Summary) {
  use title <- decode.field("title", decode.string)
  use extract <- decode.optional_field("extract", "", decode.string)
  use description <- decode.optional_field("description", "", decode.string)
  decode.success(Summary(title:, description:, extract:))
}
