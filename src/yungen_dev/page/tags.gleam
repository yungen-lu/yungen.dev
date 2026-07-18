import blogatto/post.{type Post}
import frontmatter
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import simplifile
import yungen_dev/components
import yungen_dev/layout
import yungen_dev/paths
import yungen_dev/routes
import yungen_dev/util

pub fn index(posts: List(Post(Nil))) -> Element(Nil) {
  let all = list.flat_map(posts, components.post_tags)
  let uniq = all |> list.unique |> list.sort(string.compare)
  layout.page("Tags", "All tags on the blog", [], [
    html.h1([], [element.text("Tags")]),
    html.ul(
      [attribute.class("tag-index")],
      list.map(uniq, fn(tag) {
        let n = list.count(all, fn(t) { t == tag })
        html.li([], [
          html.a([attribute.href(routes.tag(util.tag_slug(tag)) <> "/")], [
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

pub fn page(tag: String) -> fn(List(Post(Nil))) -> Element(Nil) {
  let slug = util.tag_slug(tag)
  fn(posts: List(Post(Nil))) {
    let matching =
      list.filter(posts, fn(p) {
        list.any(components.post_tags(p), fn(t) { util.tag_slug(t) == slug })
      })
    layout.page("Tagged: " <> tag, "Posts tagged " <> tag, [], [
      html.h1([], [element.text("Tagged: " <> tag)]),
      components.post_list_ul(matching),
    ])
  }
}

pub fn tag_path(tag: String) -> String {
  routes.tag(util.tag_slug(tag))
}

pub fn discover() -> List(String) {
  case simplifile.get_files(paths.content_dir) {
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
                  "tags" -> Ok(util.split_tags(v))
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
