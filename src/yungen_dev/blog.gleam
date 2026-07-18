import blogatto/config
import blogatto/config/feed/atom
import blogatto/config/feed/rss
import blogatto/config/post
import blogatto/config/post/code
import blogatto/config/robots
import blogatto/config/sitemap
import gleam/list
import gleam/option
import gleam/time/timestamp
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import smalto/lustre as smalto_lustre
import yungen_dev/constant.{site_description, site_title, site_url}
import yungen_dev/page/about
import yungen_dev/page/home
import yungen_dev/page/photos
import yungen_dev/page/post as post_page
import yungen_dev/page/reviews
import yungen_dev/page/tags
import yungen_dev/paths
import yungen_dev/routes
import yungen_dev/util

pub fn config() {
  let post_config =
    post.default()
    |> post.path(paths.content_dir)
    |> post.route_builder(fn(meta) {
      util.route_path(meta.slug, meta.language, meta.extras)
    })
    |> post.template(post_page.template)
    |> post.p(util.long_image_to_figure)
    |> post.syntax_highlighting(
      code.default() |> code.smalto_config(highlight_config()),
    )
  let rss_base =
    rss.new(site_title, site_url, site_description)
    |> rss.language("en-us")
    |> rss.generator("Blogatto")

  let atom_feed =
    atom.new(
      id: site_url <> "/",
      title: atom.PlainText(site_title),
      updated: timestamp.system_time(),
    )
    |> atom.subtitle(site_description)
    |> atom.link(atom.Link(
      href: site_url <> "/atom.xml",
      rel: option.Some("self"),
      content_type: option.Some("application/atom+xml"),
      hreflang: option.None,
      title: option.None,
      length: option.None,
    ))

  let robots_config =
    robots.RobotsConfig(sitemap_url: site_url <> "/sitemap.xml", robots: [
      robots.Robot(
        user_agent: "*",
        allowed_routes: ["/"],
        disallowed_routes: [],
      ),
    ])

  let base =
    config.new(site_url)
    |> config.output_dir(paths.dist_dir)
    |> config.post(post_config)
    |> config.route(routes.home, home.view)
    |> config.route(routes.about, about.view)
    |> config.route(routes.reviews, reviews.view)
    |> config.route(routes.photos, photos.view)
    |> config.route(routes.tags, tags.index)
    |> config.rss_feed(rss_base)
    |> config.rss_feed(rss.output(rss_base, "/index.xml"))
    |> config.atom_feed(atom_feed)
    |> config.sitemap(sitemap.new("/sitemap.xml"))
    |> config.robots(robots_config)
    |> config.static_dir(paths.static_dir)

  // Per-tag index pages. Blogatto routes are static, so discover the tag set
  // from the already-synced ./content before the build enumerates posts.
  list.fold(tags.discover(), base, fn(c, tag) {
    config.route(c, tags.tag_path(tag), tags.page(tag))
  })
}

fn tok(class_name: String) -> fn(String) -> Element(Nil) {
  fn(value) { html.span([attribute.class(class_name)], [element.text(value)]) }
}

fn highlight_config() -> smalto_lustre.Config(Nil) {
  smalto_lustre.Config(
    keyword: tok("tk-keyword"),
    string: tok("tk-string"),
    number: tok("tk-number"),
    comment: tok("tk-comment"),
    function: tok("tk-function"),
    operator: tok("tk-punct"),
    punctuation: tok("tk-punct"),
    type_: tok("tk-type"),
    module: tok("tk-type"),
    variable: tok("tk-variable"),
    constant: tok("tk-constant"),
    builtin: tok("tk-builtin"),
    tag: tok("tk-tag"),
    attribute: tok("tk-attribute"),
    selector: tok("tk-keyword"),
    property: tok("tk-attribute"),
    regex: tok("tk-string"),
    custom: fn(_name, value) {
      html.span([attribute.class("tk-custom")], [element.text(value)])
    },
  )
}
