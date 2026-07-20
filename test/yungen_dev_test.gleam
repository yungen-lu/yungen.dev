import gleam/dict
import gleam/string
import gleeunit
import gleeunit/should
import yungen_dev/github
import yungen_dev/image
import yungen_dev/sync
import yungen_dev/wikipedia

/// A converter with vips available, for embed/filename tests.
fn all_tools() -> fn(String) -> Bool {
  fn(ext) { image.convertible(ext, image.Converter(vips: True)) }
}

pub fn main() {
  gleeunit.main()
}

pub fn reformat_date_iso_offset_test() {
  sync.reformat_date("2026-04-11T22:09:43-0500")
  |> should.equal(Ok("2026-04-11 22:09:43 -05:00"))
}

pub fn reformat_date_colon_offset_test() {
  sync.reformat_date("2026-05-14T08:51:11-07:00")
  |> should.equal(Ok("2026-05-14 08:51:11 -07:00"))
}

pub fn reformat_date_dateonly_test() {
  sync.reformat_date("2022-03-09")
  |> should.equal(Ok("2022-03-09 00:00:00"))
}

pub fn reformat_date_zulu_test() {
  sync.reformat_date("2026-01-02T03:04:05Z")
  |> should.equal(Ok("2026-01-02 03:04:05"))
}

pub fn reformat_date_bad_test() {
  sync.reformat_date("")
  |> should.be_error
}

pub fn slugify_filename_test() {
  sync.slugify_filename("Pasted image 20240101.PNG")
  |> should.equal("pasted-image-20240101.png")
}

pub fn slugify_filename_multidot_test() {
  sync.slugify_filename("My Cool Photo.final.JPG")
  |> should.equal("my-cool-photo-final.jpg")
}

pub fn post_slug_curly_apostrophe_test() {
  sync.post_slug("traefik & let\u{2019}s encrypt")
  |> should.equal("traefik-lets-encrypt")
}

pub fn post_slug_straight_apostrophe_test() {
  sync.post_slug("Don't Panic")
  |> should.equal("dont-panic")
}

pub fn post_slug_plain_test() {
  sync.post_slug("Kubernetes Basics")
  |> should.equal("kubernetes-basics")
}

pub fn post_slug_cjk_fallback_test() {
  // str.slugify drops non-ASCII to ""; fall back to the title (never empty).
  sync.post_slug("耳をすませば")
  |> should.equal("耳をすませば")
}

pub fn rewrite_embeds_png_to_webp_test() {
  // PNG is converted, so the reference gets a .webp extension.
  sync.rewrite_embeds("see ![[My File.png|300]] end", all_tools())
  |> should.equal("see ![](my-file.webp) end")
}

pub fn rewrite_embeds_plain_test() {
  // SVG is not converted, so the extension is preserved.
  sync.rewrite_embeds("![[Diagram.svg]]", all_tools())
  |> should.equal("![](diagram.svg)")
}

pub fn find_embeds_test() {
  // Both png and jpg convert to webp.
  sync.find_embeds("a ![[One.png]] b ![[Two.jpg|x]] c", all_tools())
  |> should.equal([#("One.png", "one.webp"), #("Two.jpg", "two.webp")])
}

pub fn web_filename_converts_png_test() {
  sync.web_filename("My File.png", all_tools())
  |> should.equal("my-file.webp")
}

pub fn web_filename_converts_jpg_test() {
  sync.web_filename("Photo.JPG", all_tools())
  |> should.equal("photo.webp")
}

pub fn web_filename_keeps_svg_test() {
  // SVG is vector, so it keeps its extension.
  sync.web_filename("Diagram.svg", all_tools())
  |> should.equal("diagram.svg")
}

pub fn convertible_heic_test() {
  // HEIC converts directly via vips (libheif -> webp, no PNG intermediate).
  image.convertible("heic", image.Converter(vips: True))
  |> should.be_true
}

pub fn convertible_png_test() {
  // Case-insensitive on the extension.
  image.convertible("PNG", image.Converter(vips: True))
  |> should.be_true
}

pub fn convertible_jpeg_test() {
  // JPEG (the common blog-image format) now converts to WebP.
  image.convertible("JPG", image.Converter(vips: True))
  |> should.be_true
}

pub fn convertible_vector_test() {
  // SVG is vector, so it's left as-is even when vips is present.
  image.convertible("svg", image.Converter(vips: True))
  |> should.be_false
}

pub fn convertible_disabled_test() {
  // No tool: nothing is convertible, so sync keeps originals.
  image.convertible("png", image.Converter(vips: False))
  |> should.be_false
}

pub fn wikilink_resolved_test() {
  let idx = dict.from_list([#("Writing with AI", "/blog/writing-with-ai/")])
  sync.rewrite_wikilinks("see [[Writing with AI]] here", idx)
  |> should.equal("see [Writing with AI](/blog/writing-with-ai/) here")
}

pub fn wikilink_alias_test() {
  let idx = dict.from_list([#("Writing with AI", "/blog/writing-with-ai/")])
  sync.rewrite_wikilinks("[[Writing with AI|that post]]", idx)
  |> should.equal("[that post](/blog/writing-with-ai/)")
}

pub fn wikilink_heading_anchor_test() {
  let idx = dict.from_list([#("Note", "/blog/note/")])
  sync.rewrite_wikilinks("[[Note#Section]]", idx)
  |> should.equal("[Note](/blog/note/)")
}

pub fn wikilink_unresolved_test() {
  sync.rewrite_wikilinks("[[Nonexistent Note]]", dict.new())
  |> should.equal("Nonexistent Note")
}

pub fn callout_quote_keeps_inline_markdown_test() {
  sync.rewrite_callouts("> [!quote] Hello [x](y) and _z_")
  |> should.equal("> Hello [x](y) and _z_")
}

pub fn callout_foldable_note_test() {
  sync.rewrite_callouts("> [!NOTE]- Why I wrote this")
  |> should.equal("> Why I wrote this")
}

pub fn callout_multiline_body_test() {
  sync.rewrite_callouts("> [!quote] a quote\n> — Author")
  |> should.equal("> a quote\n> — Author")
}

pub fn callout_bare_marker_test() {
  // Bare marker (no text after `[!quote]`), quote on the next line.
  sync.rewrite_callouts("> [!quote]\n> Life is understood backwards")
  |> should.equal("> \n> Life is understood backwards")
}

// Annotation keys are taken from mork's rendered href, so they match the link
// the client actually sees — even when mork unescapes `\(\)` or encodes `,`.

pub fn mork_hrefs_unescapes_parens_test() {
  sync.mork_hrefs(
    "see [x](https://en.wikipedia.org/wiki/Ping_Pong_\\(manga\\)) end",
  )
  |> should.equal(["https://en.wikipedia.org/wiki/Ping_Pong_(manga)"])
}

pub fn mork_hrefs_encodes_comma_test() {
  sync.mork_hrefs("[y](https://en.wikipedia.org/wiki/Night_Is_Short,_Walk_On_Girl)")
  |> should.equal(["https://en.wikipedia.org/wiki/Night_Is_Short%2C_Walk_On_Girl"])
}

pub fn callout_non_callout_untouched_test() {
  sync.rewrite_callouts("> just a blockquote\nplain text")
  |> should.equal("> just a blockquote\nplain text")
}

pub fn excerpt_first_paragraph_test() {
  // Skips heading, embed, and blank lines; stops at the first blank.
  sync.excerpt(
    "# Title\n\n![[cover.png]]\n\nThe first real paragraph here.\n\nSecond one.",
  )
  |> should.equal("The first real paragraph here.")
}

pub fn excerpt_strips_links_test() {
  sync.excerpt("See [the docs](https://x.com) and [[Some Note|that note]] now.")
  |> should.equal("See the docs and that note now.")
}

pub fn excerpt_skips_leading_quote_test() {
  sync.excerpt("> an epigraph\n\nActual prose starts here.")
  |> should.equal("Actual prose starts here.")
}

pub fn excerpt_truncates_long_test() {
  string.repeat("alpha beta ", 40)
  |> sync.excerpt
  |> string.ends_with("…")
  |> should.be_true
}

// --- Wikipedia provider (pure helpers) ---

pub fn wikipedia_is_url_test() {
  wikipedia.is_wikipedia_url("https://en.wikipedia.org/wiki/Kubernetes")
  |> should.be_true
}

pub fn wikipedia_is_url_zh_test() {
  wikipedia.is_wikipedia_url("https://zh.wikipedia.org/wiki/Lint")
  |> should.be_true
}

pub fn wikipedia_is_url_nonwiki_test() {
  wikipedia.is_wikipedia_url("https://example.com/wiki/Kubernetes")
  |> should.be_false
}

pub fn wikipedia_summary_url_test() {
  wikipedia.summary_url("https://en.wikipedia.org/wiki/Round-robin_scheduling")
  |> should.equal(
    Ok("https://en.wikipedia.org/api/rest_v1/page/summary/Round-robin_scheduling"),
  )
}

pub fn wikipedia_summary_url_strips_fragment_test() {
  wikipedia.summary_url("https://en.wikipedia.org/wiki/Overchoice#History")
  |> should.equal(Ok("https://en.wikipedia.org/api/rest_v1/page/summary/Overchoice"))
}

pub fn wikipedia_summary_url_mobile_test() {
  wikipedia.summary_url("https://en.m.wikipedia.org/wiki/Lint")
  |> should.equal(Ok("https://en.wikipedia.org/api/rest_v1/page/summary/Lint"))
}

pub fn wikipedia_summary_url_nonwiki_test() {
  wikipedia.summary_url("https://example.com/x")
  |> should.be_error
}

// --- GitHub provider (pure helpers) ---

pub fn github_is_url_test() {
  github.is_github_url("https://github.com/traefik/traefik")
  |> should.be_true
}

pub fn github_is_url_blob_test() {
  github.is_github_url("https://github.com/mattpocock/skills/blob/main/x.md")
  |> should.be_true
}

pub fn github_is_url_http_test() {
  github.is_github_url("http://github.com/eclipse/paho.mqtt.golang")
  |> should.be_true
}

pub fn github_is_url_profile_test() {
  // A single path segment is a user/org profile, not a repo.
  github.is_github_url("https://github.com/yungen-lu")
  |> should.be_false
}

pub fn github_is_url_reserved_test() {
  github.is_github_url("https://github.com/features/copilot")
  |> should.be_false
}

pub fn github_api_url_test() {
  github.api_url("https://github.com/traefik/traefik/blob/main/x.go")
  |> should.equal(Ok("https://api.github.com/repos/traefik/traefik"))
}

pub fn github_api_url_strips_git_test() {
  github.api_url("https://github.com/axios/axios.git")
  |> should.equal(Ok("https://api.github.com/repos/axios/axios"))
}

