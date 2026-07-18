pub const home = "/"

pub const about = "/about"

pub const reviews = "/reviews"

pub const photos = "/photos"

pub const tags = "/tags"

/// A tag's index-page path, e.g. `tag("gleam") -> "/tags/gleam"`.
pub fn tag(slug: String) -> String {
  tags <> "/" <> slug
}

pub fn nav() -> List(#(String, String)) {
  [
    #("Home", home),
    #("Reviews", reviews <> "/"),
    #("Photos", photos <> "/"),
    #("About", about <> "/"),
    #("Tags", tags <> "/"),
    #("RSS", "/rss.xml"),
  ]
}
