import gleam/list
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import yungen_dev/constant.{site_title}
import yungen_dev/routes

pub fn page(
  page_title: String,
  description: String,
  scripts: List(String),
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
      ..list.map(scripts, script_tag)
    ]),
    html.body([], [site_header(), html.main([], main_content), site_footer()]),
  ])
}

fn site_header() -> Element(Nil) {
  html.header([attribute.class("masthead")], [
    html.a([attribute.href(routes.home), attribute.class("site-title")], [
      element.text(site_title),
    ]),
    html.nav(
      [],
      list.map(routes.nav(), fn(item) {
        let #(label, href) = item
        html.a([attribute.href(href)], [element.text(label)])
      }),
    ),
  ])
}

fn site_footer() -> Element(Nil) {
  html.footer([attribute.class("site-footer")], [
    element.text("© Yungen · built with Gleam + Blogatto"),
  ])
}

fn script_tag(src: String) -> Element(Nil) {
  html.script([attribute.src(src), attribute.attribute("defer", "")], "")
}
