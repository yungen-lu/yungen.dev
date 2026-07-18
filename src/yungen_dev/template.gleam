import blogatto/post.{type Post}
import filepath
import frontmatter
import gleam/dict
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleam/time/timestamp
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import mork
import simplifile
import str
import yungen_dev/constant.{site_description, site_title}
import yungen_dev/util

pub fn post(p: Post(Nil), all: List(Post(Nil))) -> Element(Nil) {
  let h1 = html.h1([], [element.text(p.title)])
  let meta =
    html.div([attribute.class("post-meta")], [
      html.time([attribute.datetime(util.fmt_date(p.date))], [
        element.text(util.fmt_date(p.date)),
      ]),
    ])
  let header_children = case post_tags(p) {
    [] -> [h1, meta]
    tags -> [h1, meta, tag_chips(tags)]
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
  page(p.title, p.description, [html.article([], article_children)])
}

pub fn home(posts: List(Post(Nil))) -> Element(Nil) {
  page(site_title, site_description, [post_list_ul(posts)])
}

pub fn about(_posts: List(Post(Nil))) -> Element(Nil) {
  let #(title, description, body_md) = read_page("./pages/about.md", "About")
  let opts =
    mork.configure()
    |> mork.tables(True)
    |> mork.autolinks(True)
    |> mork.heading_ids(True)
  let body_html =
    mork.parse_with_options(options: opts, input: body_md) |> mork.to_html
  page(title, description, [
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

pub fn reviews(posts: List(Post(Nil))) -> Element(Nil) {
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
  page("Reviews", "Films, books, and games worth remembering.", [
    html.h1([], [element.text("Reviews")]),
    html.p([attribute.class("lede")], [
      element.text(
        "Films, books, and games worth remembering — short takes, not essays.",
      ),
    ]),
    review_filters(mediums),
    html.div([attribute.class("cards")], list.map(reviews, review_card)),
  ])
}

pub fn photos(_posts: List(Post(Nil))) -> Element(Nil) {
  let groups = read_photo_groups()
  let intro = [
    html.h1([], [element.text("Photos")]),
    html.p([attribute.class("lede")], [
      element.text("Grouped by whatever fits — a place, a trip, a theme."),
    ]),
  ]
  let sections = case groups {
    [] -> [html.p([], [element.text("No photos yet.")])]
    _ -> list.map(groups, photo_group_section)
  }
  page(
    "Photos",
    "Photos, grouped by whatever fits.",
    list.append(intro, sections),
  )
}

pub fn tags_index(posts: List(Post(Nil))) -> Element(Nil) {
  let all = list.flat_map(posts, post_tags)
  let uniq = all |> list.unique |> list.sort(string.compare)
  page("Tags", "All tags on the blog", [
    html.h1([], [element.text("Tags")]),
    html.ul(
      [attribute.class("tag-index")],
      list.map(uniq, fn(tag) {
        let n = list.count(all, fn(t) { t == tag })
        html.li([], [
          html.a([attribute.href("/tags/" <> tag_slug(tag) <> "/")], [
            element.text(tag),
          ]),
          html.span([attribute.class("tag-count")], [
            element.text(" · " <> int.to_string(n)),
          ]),
        ])
      }),
    ),
  ])
}

pub fn tag_page(tag: String) -> fn(List(Post(Nil))) -> Element(Nil) {
  let slug = tag_slug(tag)
  fn(posts: List(Post(Nil))) {
    let matching =
      list.filter(posts, fn(p) {
        list.any(post_tags(p), fn(t) { tag_slug(t) == slug })
      })
    page("Tagged: " <> tag, "Posts tagged " <> tag, [
      html.h1([], [element.text("Tagged: " <> tag)]),
      post_list_ul(matching),
    ])
  }
}

fn page(
  page_title: String,
  description: String,
  main_content: List(Element(Nil)),
) -> Element(Nil) {
  html.html([attribute.lang("en")], [
    html.head([], [
      html.meta([attribute.charset("UTF-8")]),
      html.meta([
        attribute.name("viewport"),
        attribute.content("width=device-width, initial-scale=1"),
      ]),
      html.meta([
        attribute.name("color-scheme"),
        attribute.content("light dark"),
      ]),
      html.title([], page_title),
      html.meta([attribute.name("description"), attribute.content(description)]),
      html.link([attribute.rel("stylesheet"), attribute.href("/style.css")]),
      html.script(
        [attribute.src("/sidenotes.js"), attribute.attribute("defer", "")],
        "",
      ),
      html.script(
        [attribute.src("/reviews.js"), attribute.attribute("defer", "")],
        "",
      ),
      html.script(
        [attribute.src("/popup.js"), attribute.attribute("defer", "")],
        "",
      ),
    ]),
    html.body([], [site_header(), html.main([], main_content), site_footer()]),
  ])
}

fn site_header() -> Element(Nil) {
  html.header([attribute.class("masthead")], [
    html.a([attribute.href("/"), attribute.class("site-title")], [
      element.text(site_title),
    ]),
    html.nav([], [
      html.a([attribute.href("/")], [element.text("Home")]),
      html.a([attribute.href("/reviews/")], [element.text("Reviews")]),
      html.a([attribute.href("/photos/")], [element.text("Photos")]),
      html.a([attribute.href("/about/")], [element.text("About")]),
      html.a([attribute.href("/tags/")], [element.text("Tags")]),
      html.a([attribute.href("/rss.xml")], [element.text("RSS")]),
    ]),
  ])
}

fn site_footer() -> Element(Nil) {
  html.footer([attribute.class("site-footer")], [
    element.text("© Yungen · built with Gleam + Blogatto"),
  ])
}

fn post_list_ul(posts: List(Post(Nil))) -> Element(Nil) {
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

/// Read a standalone page file into (title, description, body-markdown). Falls
/// back to `default_title` + empty description/body when the file is missing.
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

fn post_tags(p: Post(Nil)) -> List(String) {
  case dict.get(p.extras, "tags") {
    Ok(raw) -> split_tags(raw)
    Error(_) -> []
  }
}

fn split_tags(raw: String) -> List(String) {
  raw
  |> string.split(",")
  |> list.map(string.trim)
  |> list.filter(fn(t) { t != "" })
}

fn tag_slug(tag: String) -> String {
  str.slugify(tag)
}

fn tag_chips(tags: List(String)) -> Element(Nil) {
  html.div(
    [attribute.class("tags")],
    list.map(tags, fn(t) {
      html.a(
        [attribute.href("/tags/" <> tag_slug(t) <> "/"), attribute.class("tag")],
        [element.text(t)],
      )
    }),
  )
}

// --- Backlinks -------------------------------------------------------------

/// Posts (other than `p`) whose rendered content links to `p`, newest first.
/// Built by scanning each post's serialized HTML for a link to `p`'s route.
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

fn is_review_post(p: Post(Nil)) -> Bool {
  dict.get(p.extras, "section") == Ok("reviews")
}

/// A long-review post as a catalog card: metadata from its frontmatter, the
/// description as the take, and a "full review →" link to its page.
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
  case simplifile.get_files("./pages/reviews") {
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

type PhotoGroup {
  PhotoGroup(
    title: String,
    description: String,
    date: String,
    images: List(String),
  )
}

fn read_photo_groups() -> List(PhotoGroup) {
  case simplifile.get_files("./pages/photos") {
    Ok(files) ->
      files
      |> list.filter(fn(f) { string.ends_with(f, ".md") })
      |> list.filter_map(read_photo_group)
      |> list.sort(fn(a, b) { string.compare(b.date, a.date) })
    Error(_) -> []
  }
}

fn read_photo_group(path: String) -> Result(PhotoGroup, Nil) {
  use raw <- result.try(simplifile.read(path) |> result.replace_error(Nil))
  let fm = frontmatter.extract(raw).frontmatter |> option.unwrap("")
  use title <- result.try(util.fm_scalar(fm, "title") |> option.to_result(Nil))
  let images = case util.fm_scalar(fm, "images") {
    option.Some(raw_imgs) ->
      raw_imgs
      |> string.split(",")
      |> list.map(string.trim)
      |> list.filter(fn(s) { s != "" })
    option.None -> []
  }
  Ok(PhotoGroup(
    title: title,
    description: util.fm_scalar(fm, "description") |> option.unwrap(""),
    date: util.fm_scalar(fm, "date") |> option.unwrap(""),
    images: images,
  ))
}

fn photo_group_section(g: PhotoGroup) -> Element(Nil) {
  let header = case g.description {
    "" -> [html.h2([], [element.text(g.title)])]
    d -> [
      html.h2([], [element.text(g.title)]),
      html.span([attribute.class("when")], [element.text(d)]),
    ]
  }
  html.section([], [
    html.div([attribute.class("album-h")], header),
    html.div(
      [attribute.class("gallery")],
      list.map(g.images, fn(src) {
        html.img([
          attribute.class("ph"),
          attribute.src(src),
          attribute.alt(g.title),
          attribute.attribute("loading", "lazy"),
        ])
      }),
    ),
  ])
}
