import blogatto/post.{type Post}
import gleam/list
import gleam/string
import gleam/time/timestamp
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import yungen_dev/assets
import yungen_dev/components
import yungen_dev/layout
import yungen_dev/util

pub fn template(p: Post(Nil), all: List(Post(Nil))) -> Element(Nil) {
  let h1 = html.h1([], [element.text(p.title)])
  let meta =
    html.div([attribute.class("post-meta")], [
      html.time([attribute.datetime(util.fmt_date(p.date))], [
        element.text(util.fmt_date(p.date)),
      ]),
    ])
  let header_children = case components.post_tags(p) {
    [] -> [h1, meta]
    tags -> [h1, meta, components.tag_chips(tags)]
  }
  let article_children =
    [
      html.header([attribute.class("post-header")], header_children),
      html.div([attribute.class("post-body")], p.contents),
    ]
    |> list.append(case backlinks(p, all) {
      [] -> []
      links -> [backlinks_section(links)]
    })
  layout.page(p.title, p.description, [assets.sidenotes_js, assets.popup_js], [
    html.article([], article_children),
  ])
}

fn backlinks(p: Post(Nil), all: List(Post(Nil))) -> List(Post(Nil)) {
  let p_route = util.route_path(p.slug, p.language, p.extras)
  let needle = "href=\"" <> p_route <> "\""
  all
  |> list.filter(fn(q) {
    util.route_path(q.slug, q.language, q.extras) != p_route
    && string.contains(post_html(q), needle)
  })
  |> list.sort(fn(a, b) { timestamp.compare(b.date, a.date) })
}

fn post_html(q: Post(Nil)) -> String {
  q.contents |> list.map(element.to_string) |> string.concat
}

fn backlinks_section(links: List(Post(Nil))) -> Element(Nil) {
  html.section([attribute.class("backlinks")], [
    html.h2([], [element.text("Links to this page")]),
    html.ul(
      [attribute.class("backlink-list")],
      list.map(links, fn(q) {
        html.li([], [
          html.a(
            [attribute.href(util.route_path(q.slug, q.language, q.extras))],
            [
              element.text(q.title),
            ],
          ),
        ])
      }),
    ),
  ])
}
