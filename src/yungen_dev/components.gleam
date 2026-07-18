import blogatto/post.{type Post}
import gleam/dict
import gleam/list
import gleam/time/timestamp
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import yungen_dev/routes
import yungen_dev/util

/// A reverse-chronological `<ul class="post-list">` (home + tag pages).
pub fn post_list_ul(posts: List(Post(Nil))) -> Element(Nil) {
  let sorted = list.sort(posts, fn(a, b) { timestamp.compare(b.date, a.date) })
  html.ul(
    [attribute.class("post-list")],
    list.map(sorted, fn(p) {
      html.li([], [
        html.a([attribute.href(util.route_path(p.slug, p.language, p.extras))], [
          element.text(p.title),
        ]),
        html.time([attribute.datetime(util.fmt_date(p.date))], [
          element.text(util.fmt_date(p.date)),
        ]),
      ])
    }),
  )
}

/// Tag names carried by a post (from its `tags` extra), else `[]`.
pub fn post_tags(p: Post(Nil)) -> List(String) {
  case dict.get(p.extras, "tags") {
    Ok(raw) -> util.split_tags(raw)
    Error(_) -> []
  }
}

/// A row of tag chips linking to each tag's index page.
pub fn tag_chips(tags: List(String)) -> Element(Nil) {
  html.div(
    [attribute.class("tags")],
    list.map(tags, fn(t) {
      html.a(
        [
          attribute.href(routes.tag(util.tag_slug(t)) <> "/"),
          attribute.class("tag"),
        ],
        [element.text(t)],
      )
    }),
  )
}
