import blogatto/post.{type Post}
import lustre/element.{type Element}
import yungen_dev/components
import yungen_dev/constant.{site_description, site_title}
import yungen_dev/layout

pub fn view(posts: List(Post(Nil))) -> Element(Nil) {
  layout.page(site_title, site_description, [], [components.post_list_ul(posts)])
}
