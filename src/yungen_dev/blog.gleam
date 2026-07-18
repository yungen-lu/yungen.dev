import blogatto/config
import blogatto/config/feed/atom
import blogatto/config/feed/rss
import blogatto/config/post
import blogatto/config/post/code
import blogatto/config/robots
import blogatto/config/sitemap
import frontmatter
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleam/time/timestamp
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import simplifile
import smalto/lustre as smalto_lustre
import str
import yungen_dev/constant.{site_description, site_title, site_url}
import yungen_dev/template
import yungen_dev/util

pub fn config() {
  let post_config =
    post.default()
    |> post.path("./content")
    |> post.route_builder(fn(meta) {
      util.route_path(meta.slug, meta.language, meta.extras)
    })
    |> post.template(template.post)
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
    |> config.output_dir("./dist")
    |> config.post(post_config)
    |> config.route("/", template.home)
    |> config.route("/about", template.about)
    |> config.route("/reviews", template.reviews)
    |> config.route("/photos", template.photos)
    |> config.route("/tags", template.tags_index)
    |> config.rss_feed(rss_base)
    |> config.rss_feed(rss.output(rss_base, "/index.xml"))
    |> config.atom_feed(atom_feed)
    |> config.sitemap(sitemap.new("/sitemap.xml"))
    |> config.robots(robots_config)
    |> config.static_dir("./static")

  // Per-tag index pages. Blogatto routes are static, so discover the tag set
  // from the already-synced ./content before the build enumerates posts.
  list.fold(discover_tags(), base, fn(c, tag) {
    config.route(c, "/tags/" <> tag_slug(tag), template.tag_page(tag))
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

fn discover_tags() -> List(String) {
  case simplifile.get_files("./content") {
    Ok(files) ->
      files
      |> list.filter(fn(f) { string.ends_with(f, ".md") })
      |> list.flat_map(tags_in_file)
      |> list.unique
      |> list.sort(string.compare)
    Error(_) -> []
  }
}

fn tags_in_file(path: String) -> List(String) {
  case simplifile.read(path) {
    Ok(content) ->
      case frontmatter.extract(content).frontmatter {
        option.Some(fm) ->
          fm
          |> string.split("\n")
          |> list.find_map(fn(line) {
            case string.split_once(line, ":") {
              Ok(#(k, v)) ->
                case string.trim(k) {
                  "tags" -> Ok(split_tags(v))
                  _ -> Error(Nil)
                }
              Error(_) -> Error(Nil)
            }
          })
          |> result.unwrap([])
        option.None -> []
      }
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
