import gleam/dict.{type Dict}
import gleam/list
import gleam/option
import gleam/string
import gleam/time/calendar
import gleam/time/timestamp
import lustre/element.{type Element}
import lustre/element/html
import str

pub fn route_path(
  slug: String,
  language: option.Option(String),
  _extras: dict.Dict(String, String),
) -> String {
  let lang = case language {
    option.Some(l) -> l <> "/"
    option.None -> ""
  }
  "/" <> lang <> slug <> "/"
}

pub fn long_image_to_figure(
  _attributes: Dict(String, String),
  children: List(Element(Nil)),
) {
  case children {
    [child] -> {
      let s = element.to_string(child) |> string.trim
      case string.starts_with(s, "<img") && !string.contains(s, "</") {
        True -> html.figure([], [child])
        False -> html.p([], children)
      }
    }
    _ -> html.p([], children)
  }
}

pub fn fmt_date(ts: timestamp.Timestamp) -> String {
  timestamp.to_rfc3339(ts, calendar.utc_offset) |> string.slice(0, 10)
}

/// First `key: value` scalar in a line-based frontmatter block.
/// TODO: Use a proper yaml parser instead of this hacky approach.
pub fn fm_scalar(fm: String, key: String) -> option.Option(String) {
  fm
  |> string.split("\n")
  |> list.find_map(fn(line) {
    case string.split_once(line, ":") {
      Ok(#(k, v)) ->
        case string.trim(k) == key {
          True -> Ok(string.trim(v))
          False -> Error(Nil)
        }
      Error(_) -> Error(Nil)
    }
  })
  |> option.from_result
}

/// URL-safe slug for a tag name.
pub fn tag_slug(tag: String) -> String {
  str.slugify(tag)
}

/// Split a comma-separated `tags` value into trimmed, non-empty names.
pub fn split_tags(raw: String) -> List(String) {
  raw
  |> string.split(",")
  |> list.map(string.trim)
  |> list.filter(fn(t) { t != "" })
}
