import blogatto/post.{type Post}
import frontmatter
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import simplifile
import yungen_dev/layout
import yungen_dev/paths
import yungen_dev/util

type PhotoGroup {
  PhotoGroup(
    title: String,
    description: String,
    date: String,
    images: List(String),
  )
}

pub fn view(_posts: List(Post(Nil))) -> Element(Nil) {
  let groups = read_photo_groups()
  let intro = [
    html.h1([], [element.text("Photos")]),
    html.p([attribute.class("lede")], [
      element.text("Grouped by whatever fits."),
    ]),
  ]
  let sections = case groups {
    [] -> [html.p([], [element.text("No photos yet.")])]
    _ -> list.map(groups, photo_group_section)
  }
  layout.page(
    "Photos",
    "Photos, grouped by whatever fits.",
    [],
    list.append(intro, sections),
  )
}

fn read_photo_groups() -> List(PhotoGroup) {
  case simplifile.get_files(paths.photos_pages_dir()) {
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
