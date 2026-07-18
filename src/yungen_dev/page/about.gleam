import blogatto/post.{type Post}
import frontmatter
import gleam/option
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import mork
import simplifile
import yungen_dev/assets
import yungen_dev/layout
import yungen_dev/paths
import yungen_dev/util

pub fn view(_posts: List(Post(Nil))) -> Element(Nil) {
  let #(title, description, body_md) = read_page(paths.about_page(), "About")
  let opts =
    mork.configure()
    |> mork.tables(True)
    |> mork.autolinks(True)
    |> mork.heading_ids(True)
  let body_html =
    mork.parse_with_options(options: opts, input: body_md) |> mork.to_html
  layout.page(title, description, [assets.popup_js], [
    html.article([], [
      html.header([attribute.class("post-header")], [
        html.h1([], [element.text(title)]),
      ]),
      element.unsafe_raw_html(
        "",
        "div",
        [attribute.class("post-body")],
        body_html,
      ),
    ]),
  ])
}

/// Read a standalone page file into `#(title, description, body-markdown)`,
/// falling back to `default_title` + empty description/body when it is missing.
fn read_page(path: String, default_title: String) -> #(String, String, String) {
  case simplifile.read(path) {
    Ok(raw) -> {
      let extracted = frontmatter.extract(raw)
      let fm = extracted.frontmatter |> option.unwrap("")
      let title = util.fm_scalar(fm, "title") |> option.unwrap(default_title)
      let description = util.fm_scalar(fm, "description") |> option.unwrap("")
      #(title, description, extracted.content)
    }
    Error(_) -> #(default_title, "", "")
  }
}
