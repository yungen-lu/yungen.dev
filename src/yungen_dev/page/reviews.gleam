import blogatto/post.{type Post}
import filepath
import frontmatter
import gleam/dict
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import mork
import simplifile
import yungen_dev/assets
import yungen_dev/layout
import yungen_dev/paths
import yungen_dev/util

type Review {
  Review(
    slug: String,
    title: String,
    medium: String,
    creator: String,
    year: String,
    cover: String,
    date: String,
    // "" for a short card; a route for a long review (renders "full review →")
    link: String,
    take: List(Element(Nil)),
  )
}

pub fn view(posts: List(Post(Nil))) -> Element(Nil) {
  let long = posts |> list.filter(is_review_post) |> list.map(post_to_review)
  let long_slugs = list.map(long, fn(r) { r.slug })
  let short =
    read_reviews()
    |> list.filter(fn(r) { !list.contains(long_slugs, r.slug) })
  let reviews =
    list.append(long, short)
    |> list.sort(fn(a, b) { string.compare(b.date, a.date) })
  let mediums =
    reviews
    |> list.map(fn(r) { r.medium })
    |> list.filter(fn(m) { m != "" })
    |> list.unique
    |> list.sort(string.compare)
  layout.page(
    "Reviews",
    "Films, books, and games worth remembering.",
    [assets.reviews_js, assets.popup_js],
    [
      html.h1([], [element.text("Reviews")]),
      html.p([attribute.class("lede")], [
        element.text(
          "Films, books, and games worth remembering — short takes, not essays.",
        ),
      ]),
      review_filters(mediums),
      html.div([attribute.class("cards")], list.map(reviews, review_card)),
    ],
  )
}

fn is_review_post(p: Post(Nil)) -> Bool {
  dict.get(p.extras, "section") == Ok("reviews")
}

fn post_to_review(p: Post(Nil)) -> Review {
  let g = fn(k) { dict.get(p.extras, k) |> result.unwrap("") }
  let take = case p.description {
    "" -> []
    d -> [html.p([], [element.text(d)])]
  }
  Review(
    slug: p.slug,
    title: p.title,
    medium: g("medium"),
    creator: g("creator"),
    year: g("year"),
    cover: g("cover"),
    date: util.fmt_date(p.date),
    link: util.route_path(p.slug, p.language, p.extras),
    take: take,
  )
}

fn read_reviews() -> List(Review) {
  case simplifile.get_files(paths.reviews_pages_dir()) {
    Ok(files) ->
      files
      |> list.filter(fn(f) { string.ends_with(f, ".md") })
      |> list.filter_map(read_review)
    Error(_) -> []
  }
}

fn read_review(path: String) -> Result(Review, Nil) {
  use raw <- result.try(simplifile.read(path) |> result.replace_error(Nil))
  let extracted = frontmatter.extract(raw)
  let fm = extracted.frontmatter |> option.unwrap("")
  use title <- result.try(util.fm_scalar(fm, "title") |> option.to_result(Nil))
  let base = filepath.base_name(path)
  let slug = case string.ends_with(base, ".md") {
    True -> string.drop_end(base, 3)
    False -> base
  }
  let g = fn(k) { util.fm_scalar(fm, k) |> option.unwrap("") }
  let body_html =
    mork.parse_with_options(
      options: mork.configure() |> mork.tables(True) |> mork.autolinks(True),
      input: extracted.content,
    )
    |> mork.to_html
  Ok(
    Review(
      slug: slug,
      title: title,
      medium: g("medium"),
      creator: g("creator"),
      year: g("year"),
      cover: g("cover"),
      date: string.slice(g("date"), 0, 10),
      link: "",
      take: [element.unsafe_raw_html("", "div", [], body_html)],
    ),
  )
}

fn review_filters(mediums: List(String)) -> Element(Nil) {
  case mediums {
    [] -> element.none()
    _ ->
      html.div(
        [attribute.class("filters")],
        [filter_pill("all", "all", True)]
          |> list.append(
            list.map(mediums, fn(m) { filter_pill(m, plural(m), False) }),
          ),
      )
  }
}

fn filter_pill(value: String, label: String, active: Bool) -> Element(Nil) {
  let cls = case active {
    True -> "pill active"
    False -> "pill"
  }
  html.button(
    [attribute.class(cls), attribute.attribute("data-filter", value)],
    [
      element.text(label),
    ],
  )
}

fn plural(medium: String) -> String {
  case medium {
    "tv" | "anime" -> medium
    m -> m <> "s"
  }
}

fn review_card(r: Review) -> Element(Nil) {
  html.article(
    [
      attribute.class("rev"),
      attribute.attribute("data-medium", r.medium),
      attribute.id(r.slug),
    ],
    [review_cover(r), html.div([attribute.class("rev__body")], review_body(r))],
  )
}

fn review_cover(r: Review) -> Element(Nil) {
  case r.cover {
    "" ->
      html.div([attribute.class("rev__cover rev__cover--ph")], [
        html.span([], [element.text(string.slice(r.title, 0, 1))]),
      ])
    url ->
      html.div([attribute.class("rev__cover")], [
        html.img([attribute.src(url), attribute.alt(r.title)]),
      ])
  }
}

fn review_body(r: Review) -> List(Element(Nil)) {
  [
    html.h3([attribute.class("rev__title")], review_title(r)),
    html.div([attribute.class("rev__meta")], [element.text(review_meta(r))]),
    html.div([attribute.class("rev__take clamp")], r.take),
    html.div([attribute.class("rev__foot")], review_foot(r)),
  ]
}

fn review_title(r: Review) -> List(Element(Nil)) {
  let base = [element.text(r.title)]
  let with_year = case r.year {
    "" -> base
    y ->
      list.append(base, [
        html.span([attribute.class("yr")], [element.text(" " <> y)]),
      ])
  }
  case r.creator {
    "" -> with_year
    c ->
      list.append(with_year, [
        html.span([attribute.class("rev__by")], [
          element.text(" · " <> creator_prefix(r.medium) <> c),
        ]),
      ])
  }
}

fn creator_prefix(medium: String) -> String {
  case medium {
    "film" | "anime" -> "dir. "
    "tv" -> "created by "
    "book" | "game" -> "by "
    _ -> ""
  }
}

fn review_meta(r: Review) -> String {
  let d = string.slice(r.date, 0, 10)
  case r.medium {
    "" -> d
    m -> d <> " · " <> m
  }
}

fn review_foot(r: Review) -> List(Element(Nil)) {
  let more =
    html.button([attribute.class("rev-more")], [element.text("expand ↓")])
  case r.link {
    "" -> [more]
    l -> [more, html.a([attribute.href(l)], [element.text("full review →")])]
  }
}
