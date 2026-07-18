import argv
import filepath
import frontmatter
import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/regexp.{Match}
import gleam/result
import gleam/string
import mork
import simplifile
import str
import yungen_dev/github
import yungen_dev/image
import yungen_dev/paths
import yungen_dev/sync/config
import yungen_dev/wikipedia

type FieldValue {
  Scalar(String)
  Items(List(String))
}

pub fn main() {
  case argv.load().arguments {
    [vault, ..] ->
      case sync(vault, paths.content_dir, config.default()) {
        Ok(n) ->
          io.println(
            "Synced " <> int.to_string(n) <> " posts into " <> paths.content_dir,
          )
        Error(e) -> io.println("Sync failed: " <> e)
      }
    [] -> io.println("usage: gleam run -m yungen_dev/sync -- <vault_dir>")
  }
}

pub fn sync(
  vault: String,
  content_dir: String,
  cfg: config.VaultConfig,
) -> Result(Int, String) {
  let blog_root = filepath.join(vault, cfg.blog_dir)
  let attachments_dir = filepath.join(vault, cfg.attachments_dir)

  use _ <- result.try(ensure_dir(blog_root))

  // Regenerate content_dir from scratch: it is a vault-derived build artifact.
  let _ = simplifile.delete(content_dir)
  use _ <- result.try(
    simplifile.create_directory_all(content_dir)
    |> result.map_error(fn(e) {
      "create " <> content_dir <> ": " <> string.inspect(e)
    }),
  )

  let pages_dir = paths.pages_dir
  let _ = simplifile.delete(pages_dir)
  use _ <- result.try(
    simplifile.create_directory_all(pages_dir)
    |> result.map_error(fn(e) {
      "create " <> pages_dir <> ": " <> string.inspect(e)
    }),
  )

  let covers_dir = paths.covers_dir()
  let _ = simplifile.delete(covers_dir)
  use _ <- result.try(
    simplifile.create_directory_all(covers_dir)
    |> result.map_error(fn(e) {
      "create " <> covers_dir <> ": " <> string.inspect(e)
    }),
  )

  let photos_dir = paths.photos_dir()
  let _ = simplifile.delete(photos_dir)
  use _ <- result.try(
    simplifile.create_directory_all(photos_dir)
    |> result.map_error(fn(e) {
      "create " <> photos_dir <> ": " <> string.inspect(e)
    }),
  )

  let metadata_dir = paths.metadata_dir()
  let wiki_cache = read_external_cache(metadata_dir)
  let _ = simplifile.delete(metadata_dir)
  use _ <- result.try(
    simplifile.create_directory_all(metadata_dir)
    |> result.map_error(fn(e) {
      "create " <> metadata_dir <> ": " <> string.inspect(e)
    }),
  )

  let attachments = build_attachment_index(attachments_dir)

  // Detect image tools once; `conv` decides which attachment extensions become
  // WebP. When a tool is missing, nothing is convertible and files are copied
  // as-is (references keep their original extension), so sync still succeeds.
  let converter = image.detect()
  let conv = fn(ext) { image.convertible(ext, converter) }

  use files <- result.try(
    simplifile.get_files(blog_root)
    |> result.map_error(fn(e) {
      "list " <> blog_root <> ": " <> string.inspect(e)
    }),
  )

  let md_files =
    files
    |> list.filter(fn(p) {
      string.ends_with(p, ".md")
      && !string.starts_with(filepath.base_name(p), ".")
    })

  // Pass 1: map every publishable note name -> its route, so `[[wikilinks]]`
  // can be resolved to real links in pass 2.
  let note_index = build_note_index(md_files, blog_root)

  let written =
    list.fold(md_files, 0, fn(count, f) {
      case
        process_file(
          f,
          content_dir,
          covers_dir,
          photos_dir,
          attachments,
          note_index,
          conv,
          cfg,
        )
      {
        Ok(True) -> count + 1
        Ok(False) -> count
        Error(msg) -> {
          io.println("WARN: skipped " <> f <> " — " <> msg)
          count
        }
      }
    })

  // Short reviews: shared notes from the configured review sources (opt-in via
  // `share: true`), medium taken from the source. These become /reviews cards,
  // not posts.
  cfg.review_sources
  |> list.each(fn(source) {
    let dir = filepath.join(vault, source.dir)
    case simplifile.get_files(dir) {
      Ok(fs) ->
        fs
        |> list.filter(fn(p) {
          string.ends_with(p, ".md")
          && !string.starts_with(filepath.base_name(p), ".")
        })
        |> list.each(fn(f) {
          process_shared_review(
            f,
            source.medium,
            covers_dir,
            attachments,
            note_index,
            conv,
          )
        })
      Error(_) -> Nil
    }
  })

  // Layer C: the link-popup annotations map. Internal posts keyed by route, plus
  // recognized external links (fetched at sync time, cached across runs), keyed
  // by URL. Consumed by static/popup.js on hover.
  let internal = build_annotations(md_files, cfg)
  // External links come from blog posts AND shared review-source notes (whose
  // bodies aren't in md_files), so short-review links get popups too.
  let external_urls =
    list.append(
      collect_external_urls(md_files, cfg),
      collect_shared_review_urls(vault, cfg),
    )
    |> list.unique
  let external = resolve_external(external_urls, wiki_cache)
  use _ <- result.try(write_annotations(
    list.append(internal, external),
    metadata_dir,
  ))

  Ok(written)
}

/// Process one note. Returns `Ok(True)` when a post was written, `Ok(False)`
/// when the note was intentionally skipped (draft / About), `Error` on failure.
fn process_file(
  md_path: String,
  content_dir: String,
  covers_dir: String,
  photos_dir: String,
  attachments: Dict(String, String),
  note_index: Dict(String, String),
  conv: fn(String) -> Bool,
  cfg: config.VaultConfig,
) -> Result(Bool, String) {
  use raw <- result.try(
    simplifile.read(md_path)
    |> result.map_error(fn(e) {
      "read " <> md_path <> ": " <> string.inspect(e)
    }),
  )

  let extracted = frontmatter.extract(raw)
  let entries = case extracted.frontmatter {
    Some(fm) -> parse_frontmatter(fm)
    None -> []
  }

  let is_draft = case get_scalar(entries, "draft") {
    Some(v) -> string.lowercase(string.trim(v)) == "true"
    None -> False
  }

  // About is a standalone page (no date, not in the feed), not a post.
  let is_about = filepath.base_name(md_path) == cfg.about_filename
  // Photo-album notes are for the /photos gallery, not posts.
  let is_photo = string.contains(md_path, cfg.photos_marker)
  // Long reviews (Notes/Blog/Reviews) ARE posts — `section: reviews` (stamped in
  // the post branch) lets blog.gleam also surface each as a /reviews card linking
  // to its page. Short reviews come from Movie/Anime/Book (process_shared_review).

  case is_draft, is_about, is_photo {
    True, _, _ -> Ok(False)
    False, True, _ ->
      write_about_page(entries, extracted.content, note_index, conv)
    False, False, True ->
      write_photo_group(
        entries,
        extracted.content,
        photos_dir,
        attachments,
        conv,
      )
    False, False, False -> {
      use title <- result.try(
        get_scalar(entries, "title")
        |> option.to_result("no title in " <> md_path),
      )

      // Prefer publishDate (the real publish date) over date (file mtime).
      let date_raw = case non_empty(get_scalar(entries, "publishDate")) {
        Some(pd) -> pd
        None -> get_scalar(entries, "date") |> option.unwrap("")
      }
      use date <- result.try(reformat_date(date_raw))

      let description = get_scalar(entries, "description") |> option.unwrap("")
      let section = section_for(md_path, cfg)
      let tags = get_list(entries, "tags")
      let slug = post_slug(title)
      let body = extracted.content

      // A review post (section: reviews) carries a cover for its /reviews card.
      let cover = case section, non_empty(get_scalar(entries, "coverImage")) {
        Some("reviews"), Some(raw) ->
          copy_cover(raw, slug, covers_dir, attachments, conv)
        _, _ -> ""
      }

      let out_dir = filepath.join(content_dir, slug)
      use _ <- result.try(
        simplifile.create_directory_all(out_dir)
        |> result.map_error(fn(e) {
          "mkdir " <> out_dir <> ": " <> string.inspect(e)
        }),
      )

      let fm =
        build_frontmatter(title, slug, date, description, section, tags, cover)
      let out_md = filepath.join(out_dir, "index.md")
      use _ <- result.try(
        simplifile.write(
          to: out_md,
          contents: "---\n"
            <> fm
            <> "---\n"
            <> {
            body
            |> rewrite_embeds(conv)
            |> rewrite_callouts
            |> rewrite_wikilinks(note_index)
          },
        )
        |> result.map_error(fn(e) {
          "write " <> out_md <> ": " <> string.inspect(e)
        }),
      )

      // Gather referenced attachments into the page bundle (converting to WebP).
      find_embeds(body, conv)
      |> list.each(fn(pair) {
        let #(orig, new_name) = pair
        case dict.get(attachments, orig) {
          Ok(src) -> place_attachment(src, filepath.join(out_dir, new_name))
          Error(_) ->
            io.println(
              "WARN: attachment '"
              <> orig
              <> "' referenced by "
              <> filepath.base_name(md_path)
              <> " not found",
            )
        }
      })

      Ok(True)
    }
  }
}

// --- Frontmatter ---

/// Parse a raw frontmatter block into ordered `key -> value` entries,
/// recognizing single-line scalars and `- item` YAML lists.
fn parse_frontmatter(raw: String) -> List(#(String, FieldValue)) {
  raw
  |> string.split("\n")
  |> list.fold([], fn(acc, line) {
    let t = string.trim(line)
    case t {
      "" -> acc
      "#" <> _ -> acc
      _ ->
        case is_list_item(t) {
          True -> {
            let item = strip_dash(t)
            case acc {
              [#(k, Items(items)), ..rest] -> [
                #(k, Items([item, ..items])),
                ..rest
              ]
              [#(k, Scalar("")), ..rest] -> [#(k, Items([item])), ..rest]
              _ -> acc
            }
          }
          False ->
            case string.split_once(t, ":") {
              Ok(#(k, v)) -> [
                #(string.trim(k), Scalar(strip_quotes(string.trim(v)))),
                ..acc
              ]
              Error(_) -> acc
            }
        }
    }
  })
  |> list.reverse
}

fn is_list_item(t: String) -> Bool {
  string.starts_with(t, "- ") || t == "-"
}

fn strip_dash(t: String) -> String {
  case t {
    "- " <> rest -> string.trim(rest)
    _ -> ""
  }
}

fn strip_quotes(v: String) -> String {
  case string.first(v), string.last(v) {
    Ok("\""), Ok("\"") -> v |> string.drop_start(1) |> string.drop_end(1)
    Ok("'"), Ok("'") -> v |> string.drop_start(1) |> string.drop_end(1)
    _, _ -> v
  }
}

fn get_scalar(
  entries: List(#(String, FieldValue)),
  key: String,
) -> Option(String) {
  entries
  |> list.find_map(fn(e) {
    case e {
      #(k, Scalar(v)) if k == key -> Ok(v)
      _ -> Error(Nil)
    }
  })
  |> option.from_result
}

fn non_empty(o: Option(String)) -> Option(String) {
  case o {
    Some(v) ->
      case string.trim(v) {
        "" -> None
        s -> Some(s)
      }
    None -> None
  }
}

/// Write the About note as a standalone page (./pages/about.md), not a post:
/// no date, not in the feed. The same body transforms as posts are applied so
/// any Obsidian syntax resolves; blog.gleam renders it at /about. Returns
/// Ok(False) since no post was written.
fn write_about_page(
  entries: List(#(String, FieldValue)),
  body: String,
  note_index: Dict(String, String),
  conv: fn(String) -> Bool,
) -> Result(Bool, String) {
  let title = get_scalar(entries, "title") |> option.unwrap("About")
  let description = get_scalar(entries, "description") |> option.unwrap("")
  let transformed =
    body
    |> rewrite_embeds(conv)
    |> rewrite_callouts
    |> rewrite_wikilinks(note_index)
  let fm =
    string.join(["title: " <> title, "description: " <> description], "\n")
    <> "\n"
  let out_md = paths.about_page()
  simplifile.write(
    to: out_md,
    contents: "---\n" <> fm <> "---\n" <> transformed,
  )
  |> result.map_error(fn(e) { "write " <> out_md <> ": " <> string.inspect(e) })
  |> result.map(fn(_) { False })
}

/// Read a Movie/Anime/Book note; if it opts in with `share: true`, write it as a
/// short review card (medium comes from the note's folder/type). Best-effort:
/// logs and skips on read/parse trouble.
fn process_shared_review(
  path: String,
  medium: String,
  covers_dir: String,
  attachments: Dict(String, String),
  note_index: Dict(String, String),
  conv: fn(String) -> Bool,
) -> Nil {
  case simplifile.read(path) {
    Error(_) -> Nil
    Ok(raw) -> {
      let extracted = frontmatter.extract(raw)
      let entries = case extracted.frontmatter {
        Some(fm) -> parse_frontmatter(fm)
        None -> []
      }
      let share = case get_scalar(entries, "share") {
        Some(v) -> string.lowercase(string.trim(v)) == "true"
        None -> False
      }
      case share {
        False -> Nil
        True ->
          case
            write_review(
              entries,
              extracted.content,
              medium,
              covers_dir,
              attachments,
              note_index,
              conv,
            )
          {
            Ok(_) -> Nil
            Error(e) -> io.println("WARN: review " <> path <> " — " <> e)
          }
      }
    }
  }
}

/// Write a shared Movie/Anime/Book note as a short review card under
/// ./pages/reviews (`medium` passed in from the note type). Not a post: no page,
/// not in home/feed; blog.gleam merges these with the long-review posts.
fn write_review(
  entries: List(#(String, FieldValue)),
  body: String,
  medium: String,
  covers_dir: String,
  attachments: Dict(String, String),
  note_index: Dict(String, String),
  conv: fn(String) -> Bool,
) -> Result(Bool, String) {
  let title = get_scalar(entries, "title") |> option.unwrap("Untitled")
  let slug = post_slug(title)
  // Creator: an explicit `creator`, else a book's `author`.
  let creator = case non_empty(get_scalar(entries, "creator")) {
    Some(c) -> c
    None -> get_scalar(entries, "author") |> option.unwrap("")
  }
  let year = get_scalar(entries, "year") |> option.unwrap("")
  // Order by when finished, falling back to publish/file date.
  let date_raw =
    non_empty(get_scalar(entries, "dateCompleted"))
    |> option.or(non_empty(get_scalar(entries, "publishDate")))
    |> option.or(non_empty(get_scalar(entries, "date")))
    |> option.unwrap("")
  let date = reformat_date(date_raw) |> result.unwrap(date_raw)
  let cover = case non_empty(get_scalar(entries, "coverImage")) {
    Some(raw) -> copy_cover(raw, slug, covers_dir, attachments, conv)
    None -> ""
  }

  let reviews_dir = paths.reviews_pages_dir()
  use _ <- result.try(
    simplifile.create_directory_all(reviews_dir)
    |> result.map_error(fn(e) {
      "mkdir " <> reviews_dir <> ": " <> string.inspect(e)
    }),
  )

  let fm = review_frontmatter(title, medium, creator, year, cover, date, "")
  let out_md = filepath.join(reviews_dir, slug <> ".md")
  let take =
    body
    |> rewrite_embeds(conv)
    |> rewrite_callouts
    |> rewrite_wikilinks(note_index)
  simplifile.write(to: out_md, contents: "---\n" <> fm <> "---\n" <> take)
  |> result.map_error(fn(e) { "write " <> out_md <> ": " <> string.inspect(e) })
  |> result.map(fn(_) { False })
}

/// Copy a review's cover from vault Attachments into covers_dir as `<slug>.<ext>`
/// (WebP when convertible), returning its site-root URL (or "" when the
/// referenced file isn't found).
fn copy_cover(
  raw: String,
  slug: String,
  covers_dir: String,
  attachments: Dict(String, String),
  conv: fn(String) -> Bool,
) -> String {
  let name = strip_embed_markers(raw)
  case dict.get(attachments, name) {
    Ok(src) -> {
      let ext = case conv(file_ext(name)) {
        True -> "webp"
        False -> file_ext(name)
      }
      let dest_name = slug <> "." <> ext
      place_attachment(src, filepath.join(covers_dir, dest_name))
      paths.covers_url() <> "/" <> dest_name
    }
    Error(_) -> {
      io.println("WARN: cover '" <> name <> "' not found for " <> slug)
      ""
    }
  }
}

/// Strip Obsidian embed/link markers and any `|alias` from a cover reference,
/// leaving the bare filename.
fn strip_embed_markers(raw: String) -> String {
  let s = string.trim(raw)
  let s = case string.starts_with(s, "![[") {
    True -> string.drop_start(s, 3)
    False ->
      case string.starts_with(s, "[[") {
        True -> string.drop_start(s, 2)
        False -> s
      }
  }
  let s = case string.ends_with(s, "]]") {
    True -> string.drop_end(s, 2)
    False -> s
  }
  case string.split_once(s, "|") {
    Ok(#(n, _)) -> string.trim(n)
    Error(_) -> string.trim(s)
  }
}

fn file_ext(name: String) -> String {
  case list.reverse(string.split(name, ".")) {
    [ext, _rest, ..] -> string.lowercase(ext)
    _ -> "jpg"
  }
}

/// Join the non-empty review fields into a line-based frontmatter block.
fn review_frontmatter(
  title: String,
  medium: String,
  creator: String,
  year: String,
  cover: String,
  date: String,
  link: String,
) -> String {
  [
    #("title", title),
    #("medium", medium),
    #("creator", creator),
    #("year", year),
    #("cover", cover),
    #("date", date),
    #("link", link),
  ]
  |> list.filter(fn(kv) { kv.1 != "" })
  |> list.map(fn(kv) { kv.0 <> ": " <> kv.1 })
  |> string.join("\n")
  |> string.append("\n")
}

/// Write a photo album as a catalog entry under ./pages/photos: the group's
/// free-text title + optional description + the images it embeds (copied into
/// ./static/photos/<slug> and recorded as a comma-separated `images` list).
/// blog.gleam renders the gallery. Returns Ok(False) — not a post.
fn write_photo_group(
  entries: List(#(String, FieldValue)),
  body: String,
  photos_dir: String,
  attachments: Dict(String, String),
  conv: fn(String) -> Bool,
) -> Result(Bool, String) {
  let title = get_scalar(entries, "title") |> option.unwrap("Untitled")
  let slug = post_slug(title)
  let description = get_scalar(entries, "description") |> option.unwrap("")
  let date_raw = case non_empty(get_scalar(entries, "publishDate")) {
    Some(pd) -> pd
    None -> get_scalar(entries, "date") |> option.unwrap("")
  }
  let date = reformat_date(date_raw) |> result.unwrap(date_raw)

  let group_dir = filepath.join(photos_dir, slug)
  use _ <- result.try(
    simplifile.create_directory_all(group_dir)
    |> result.map_error(fn(e) {
      "mkdir " <> group_dir <> ": " <> string.inspect(e)
    }),
  )

  // Copy each embedded image into the group's asset dir (converting to WebP);
  // collect its URL.
  let urls =
    find_embeds(body, conv)
    |> list.filter_map(fn(pair) {
      let #(orig, new_name) = pair
      case dict.get(attachments, orig) {
        Ok(src) -> {
          place_attachment(src, filepath.join(group_dir, new_name))
          Ok(paths.photos_url() <> "/" <> slug <> "/" <> new_name)
        }
        Error(_) -> {
          io.println("WARN: photo '" <> orig <> "' not found for " <> slug)
          Error(Nil)
        }
      }
    })

  let fm =
    [
      #("title", title),
      #("description", description),
      #("date", date),
      #("images", string.join(urls, ", ")),
    ]
    |> list.filter(fn(kv) { kv.1 != "" })
    |> list.map(fn(kv) { kv.0 <> ": " <> kv.1 })
    |> string.join("\n")
    |> string.append("\n")

  let photos_pages = paths.photos_pages_dir()
  use _ <- result.try(
    simplifile.create_directory_all(photos_pages)
    |> result.map_error(fn(e) {
      "mkdir " <> photos_pages <> ": " <> string.inspect(e)
    }),
  )
  let out_md = filepath.join(photos_pages, slug <> ".md")
  simplifile.write(to: out_md, contents: "---\n" <> fm <> "---\n")
  |> result.map_error(fn(e) { "write " <> out_md <> ": " <> string.inspect(e) })
  |> result.map(fn(_) { False })
}

fn build_frontmatter(
  title: String,
  slug: String,
  date: String,
  description: String,
  section: Option(String),
  tags: List(String),
  cover: String,
) -> String {
  // Stamp `slug` explicitly so Blogatto uses our apostrophe-stripped slug
  // (post_slug) rather than recomputing str.slugify(title); keeps the URL, the
  // page-bundle dir, and the wikilink index all agreeing.
  let base = [
    "title: " <> title,
    "slug: " <> slug,
    "date: " <> date,
    "description: " <> description,
  ]
  let with_section = case section {
    Some(s) -> list.append(base, ["section: " <> s])
    None -> base
  }
  // Blogatto's frontmatter reader is line-based, so a YAML list won't parse;
  // emit tags as a single comma-separated value that lands in `extras`.
  let with_tags = case tags {
    [] -> with_section
    _ -> list.append(with_section, ["tags: " <> string.join(tags, ", ")])
  }
  let with_cover = case cover {
    "" -> with_tags
    c -> list.append(with_tags, ["cover: " <> c])
  }
  string.join(with_cover, "\n") <> "\n"
}

/// The items of a list-valued frontmatter entry (e.g. `tags`), in source order.
fn get_list(entries: List(#(String, FieldValue)), key: String) -> List(String) {
  entries
  |> list.find_map(fn(e) {
    case e {
      #(k, Items(items)) if k == key -> Ok(list.reverse(items))
      _ -> Error(Nil)
    }
  })
  |> result.unwrap([])
}

// --- Dates ---

/// Reformat a vault date into Blogatto's `YYYY-MM-DD HH:MM:SS [+HH:MM]`.
///
/// Accepts ISO datetimes (`2026-04-11T22:09:43-0500`, `...Z`, colon or
/// colonless offset) and bare dates (`2022-03-09`, expanded to midnight).
pub fn reformat_date(raw: String) -> Result(String, String) {
  let raw = string.trim(raw)
  let assert Ok(date_only) = regexp.from_string("^(\\d{4}-\\d{2}-\\d{2})$")
  let assert Ok(dt) =
    regexp.from_string(
      "^(\\d{4}-\\d{2}-\\d{2})[T ](\\d{2}:\\d{2}:\\d{2})(?:\\.\\d+)?(Z|[+-]\\d{2}:?\\d{2})?$",
    )
  case regexp.check(date_only, raw) {
    True -> Ok(raw <> " 00:00:00")
    False ->
      case regexp.scan(dt, raw) {
        [Match(_, subs)] ->
          case subs {
            [Some(d), Some(t)] -> Ok(d <> " " <> t)
            [Some(d), Some(t), None] -> Ok(d <> " " <> t)
            [Some(d), Some(t), Some("Z")] -> Ok(d <> " " <> t)
            [Some(d), Some(t), Some(off)] ->
              Ok(d <> " " <> t <> " " <> normalize_offset(off))
            _ -> Error("unparseable date: " <> raw)
          }
        _ -> Error("unparseable date: " <> raw)
      }
  }
}

fn normalize_offset(off: String) -> String {
  case string.contains(off, ":") {
    True -> off
    False -> string.slice(off, 0, 3) <> ":" <> string.slice(off, 3, 2)
  }
}

// --- Image embeds ---

fn embed_regexp() -> regexp.Regexp {
  let assert Ok(re) =
    regexp.from_string("!\\[\\[([^\\]|]+)(?:\\|[^\\]]*)?\\]\\]")
  re
}

/// Rewrite `![[name.ext|mod]]` embeds to CommonMark `![](slug.ext)`, mapping the
/// extension to `.webp` when `conv` says that source type is converted.
pub fn rewrite_embeds(body: String, conv: fn(String) -> Bool) -> String {
  regexp.match_map(embed_regexp(), body, fn(m) {
    case m.submatches {
      [Some(inner), ..] ->
        "![](" <> web_filename(string.trim(inner), conv) <> ")"
      _ -> m.content
    }
  })
}

/// The `(original_name, output_name)` pairs referenced by embeds in `body`. The
/// output name is the slugified filename, with a `.webp` extension when `conv`
/// says that source type is converted (so it matches `rewrite_embeds`).
pub fn find_embeds(
  body: String,
  conv: fn(String) -> Bool,
) -> List(#(String, String)) {
  embed_regexp()
  |> regexp.scan(body)
  |> list.filter_map(fn(m) {
    case m.submatches {
      [Some(inner), ..] -> {
        let orig = string.trim(inner)
        Ok(#(orig, web_filename(orig, conv)))
      }
      _ -> Error(Nil)
    }
  })
}

/// The output filename for an embedded image: the slugified name, its extension
/// swapped to `.webp` when the source type is converted.
pub fn web_filename(name: String, conv: fn(String) -> Bool) -> String {
  let slugged = slugify_filename(name)
  case conv(file_ext(name)) {
    True -> swap_ext_webp(slugged)
    False -> slugged
  }
}

fn swap_ext_webp(name: String) -> String {
  case list.reverse(string.split(name, ".")) {
    [_ext, ..rest] -> string.join(list.reverse(rest), ".") <> ".webp"
    _ -> name <> ".webp"
  }
}

/// Place an attachment at `dest` (WebP conversion or verbatim copy). Aborts the
/// sync on failure: by the time we get here the markdown/frontmatter already
/// points at `dest`, so a silent failure would ship a broken link (e.g. a missing
/// HEVC decoder makes vips fail, and the site would reference a `.webp` that was
/// never written). Failing loud lets CI catch it before deploying.
fn place_attachment(src: String, dest: String) -> Nil {
  case image.place(src, dest) {
    Ok(_) -> Nil
    Error(e) -> {
      io.println("ERROR: " <> e)
      panic as "sync aborted: image conversion/copy failed (see ERROR above)"
    }
  }
}

/// Slug for a post URL. Strips apostrophes (straight and curly) before
/// slugifying, so "traefik & let's encrypt" becomes "traefik-lets-encrypt" (as
/// the old Hugo site produced) instead of str.slugify's "traefik-let-s-encrypt".
/// `str.slugify` drops all non-ASCII, so a CJK-only title ("耳をすませば") would
/// slugify to "" — fall back to the title itself (spaces/slashes hyphenated) so
/// the slug is never empty (matters for the many Japanese review titles).
pub fn post_slug(title: String) -> String {
  let slug =
    title
    |> string.replace("'", "")
    |> string.replace("\u{2019}", "")
    |> str.slugify
  case slug {
    "" ->
      title
      |> string.trim
      |> string.replace("/", "-")
      |> string.replace(" ", "-")
    _ -> slug
  }
}

/// Slugify a filename while preserving (and lowercasing) its extension.
pub fn slugify_filename(name: String) -> String {
  let name = string.trim(name)
  case list.reverse(string.split(name, ".")) {
    [ext, second, ..rest] -> {
      let stem = [second, ..rest] |> list.reverse |> string.join(".")
      str.slugify(stem) <> "." <> string.lowercase(ext)
    }
    _ -> str.slugify(name)
  }
}

// --- Callouts ---

fn callout_regexp() -> regexp.Regexp {
  let assert Ok(re) =
    regexp.from_string("^(\\s*>[\\s>]*)\\[![A-Za-z]+\\][-+]?\\s?(.*)$")
  re
}

/// Strip Obsidian callout markers (`> [!quote] …`, `> [!NOTE]- …`) so the block
/// renders as a plain blockquote, keeping the body and its inline markdown.
/// (CommonMark can't attach a class, so per-type boxes aren't possible here.)
pub fn rewrite_callouts(body: String) -> String {
  let re = callout_regexp()
  body
  |> string.split("\n")
  |> list.map(fn(line) {
    case regexp.scan(re, line) {
      [Match(_, [Some(prefix), Some(rest)])] -> prefix <> rest
      // Bare marker (`> [!quote]` with no text after it): the trailing capture
      // is empty, which gleam_regexp reports as None/absent — keep just the
      // blockquote prefix.
      [Match(_, [Some(prefix), ..])] -> prefix
      _ -> line
    }
  })
  |> string.join("\n")
}

// --- Wikilinks ---

/// Map every publishable note name (filename stem AND title) to its route path,
/// so `[[name]]` body links can be resolved. Drafts and About are excluded, so
/// links to them fall through to plain text.
fn build_note_index(
  files: List(String),
  _blog_root: String,
) -> Dict(String, String) {
  list.fold(files, dict.new(), fn(acc, path) {
    case simplifile.read(path) {
      Error(_) -> acc
      Ok(content) -> {
        let entries = case frontmatter.extract(content).frontmatter {
          Some(fm) -> parse_frontmatter(fm)
          None -> []
        }
        let is_draft = case get_scalar(entries, "draft") {
          Some(v) -> string.lowercase(string.trim(v)) == "true"
          None -> False
        }
        let is_about = filepath.base_name(path) == "About.md"
        case is_draft || is_about, get_scalar(entries, "title") {
          False, Some(title) -> {
            // Flat /<slug>/ routes, matching route_path in blog.gleam so
            // rewritten wikilinks resolve to the pages Blogatto writes.
            let route = "/" <> post_slug(title) <> "/"
            acc
            |> dict.insert(md_stem(filepath.base_name(path)), route)
            |> dict.insert(string.trim(title), route)
          }
          _, _ -> acc
        }
      }
    }
  })
}

fn md_stem(filename: String) -> String {
  case string.ends_with(filename, ".md") {
    True -> string.drop_end(filename, 3)
    False -> filename
  }
}

fn wikilink_regexp() -> regexp.Regexp {
  let assert Ok(re) = regexp.from_string("\\[\\[([^\\]]+)\\]\\]")
  re
}

/// Rewrite Obsidian `[[note]]` / `[[note|alias]]` links to markdown links via
/// `index`. Unresolvable targets (drafts, About, non-posts) become plain text.
/// Run AFTER `rewrite_embeds` so `![[...]]` embeds are already gone.
pub fn rewrite_wikilinks(body: String, index: Dict(String, String)) -> String {
  regexp.match_map(wikilink_regexp(), body, fn(m) {
    case m.submatches {
      [Some(inner), ..] -> resolve_wikilink(inner, index)
      _ -> m.content
    }
  })
}

fn resolve_wikilink(inner: String, index: Dict(String, String)) -> String {
  let #(target, alias) = case string.split_once(inner, "|") {
    Ok(#(t, a)) -> #(t, Some(string.trim(a)))
    Error(_) -> #(inner, None)
  }
  // drop any #heading / #^block anchor when resolving the note name
  let name = case string.split_once(target, "#") {
    Ok(#(n, _)) -> string.trim(n)
    Error(_) -> string.trim(target)
  }
  let display = case alias {
    Some(a) -> a
    None -> name
  }
  case dict.get(index, name) {
    Ok(route) -> "[" <> display <> "](" <> route <> ")"
    Error(_) -> display
  }
}

// --- Annotations (Layer C: link popups) ------------------------------------

/// A link-popup annotation: what a reader sees when hovering an internal link.
type Annotation {
  Annotation(title: String, byline: String, abstract: String)
}

/// Build one annotation per publishable post, keyed by its flat `/<slug>/`
/// route (matching route_path in blog.gleam and the wikilink index, so hovered
/// links resolve). Same publishability rule as the post pass — drafts, About,
/// and photo albums are excluded. The abstract is the post's `description`, or a
/// first-paragraph excerpt when that is empty.
fn build_annotations(
  files: List(String),
  cfg: config.VaultConfig,
) -> List(#(String, Annotation)) {
  list.filter_map(files, fn(path) {
    case simplifile.read(path) {
      Error(_) -> Error(Nil)
      Ok(raw) -> {
        let extracted = frontmatter.extract(raw)
        let entries = case extracted.frontmatter {
          Some(fm) -> parse_frontmatter(fm)
          None -> []
        }
        case is_publishable(path, entries, cfg), get_scalar(entries, "title") {
          True, Some(title) -> {
            let route = "/" <> post_slug(string.trim(title)) <> "/"
            let date_raw = case non_empty(get_scalar(entries, "publishDate")) {
              Some(pd) -> pd
              None -> get_scalar(entries, "date") |> option.unwrap("")
            }
            let date =
              reformat_date(date_raw)
              |> result.unwrap(date_raw)
              |> string.slice(0, 10)
            let tags = get_list(entries, "tags")
            let abstract = case non_empty(get_scalar(entries, "description")) {
              Some(d) -> d
              None -> excerpt(extracted.content)
            }
            Ok(#(
              route,
              Annotation(string.trim(title), byline(date, tags), abstract),
            ))
          }
          _, _ -> Error(Nil)
        }
      }
    }
  })
}

/// Compact metadata line for a popup: date, then tags.
fn byline(date: String, tags: List(String)) -> String {
  case date, tags {
    "", [] -> ""
    d, [] -> d
    "", ts -> string.join(ts, ", ")
    d, ts -> d <> " · " <> string.join(ts, ", ")
  }
}

/// A plain-text preview of a note body: its first prose paragraph, stripped of
/// markdown/Obsidian syntax and truncated. Used as the popup abstract when a
/// post has no `description`.
pub fn excerpt(body: String) -> String {
  body
  |> string.split("\n")
  |> list.map(string.trim)
  |> drop_until_prose
  |> take_paragraph
  |> string.join(" ")
  |> strip_inline_markdown
  |> truncate(240)
}

fn drop_until_prose(lines: List(String)) -> List(String) {
  case lines {
    [] -> []
    [line, ..rest] ->
      case is_prose_line(line) {
        True -> lines
        False -> drop_until_prose(rest)
      }
  }
}

/// A body line that begins ordinary prose — not blank, heading, quote, embed,
/// image, code fence, rule, list item, or table row.
fn is_prose_line(line: String) -> Bool {
  line != ""
  && !string.starts_with(line, "#")
  && !string.starts_with(line, ">")
  && !string.starts_with(line, "![")
  && !string.starts_with(line, "```")
  && !string.starts_with(line, "~~~")
  && !string.starts_with(line, "---")
  && !string.starts_with(line, "- ")
  && !string.starts_with(line, "* ")
  && !string.starts_with(line, "+ ")
  && !string.starts_with(line, "|")
}

fn take_paragraph(lines: List(String)) -> List(String) {
  case lines {
    [] -> []
    ["", ..] -> []
    [line, ..rest] -> [line, ..take_paragraph(rest)]
  }
}

/// Reduce a line of markdown/Obsidian to readable plain text: wikilinks and
/// markdown links to their display text; bold/code/strikethrough markers
/// removed; runs of whitespace collapsed. Single `*`/`_` are left alone so
/// snake_case words survive.
fn strip_inline_markdown(s: String) -> String {
  let with_wiki =
    regexp.match_map(wikilink_regexp(), s, fn(m) {
      case m.submatches {
        [Some(inner), ..] -> wikilink_display(inner)
        _ -> m.content
      }
    })
  let assert Ok(link_re) = regexp.from_string("\\[([^\\]]+)\\]\\([^)]*\\)")
  regexp.match_map(link_re, with_wiki, fn(m) {
    case m.submatches {
      [Some(text), ..] -> text
      _ -> m.content
    }
  })
  |> string.replace("**", "")
  |> string.replace("`", "")
  |> string.replace("~~", "")
  |> collapse_ws
}

/// The visible text of a `[[target|alias]]` / `[[target#heading]]` wikilink.
fn wikilink_display(inner: String) -> String {
  case string.split_once(inner, "|") {
    Ok(#(_, alias)) -> string.trim(alias)
    Error(_) ->
      case string.split_once(inner, "#") {
        Ok(#(name, _)) -> string.trim(name)
        Error(_) -> string.trim(inner)
      }
  }
}

fn collapse_ws(s: String) -> String {
  let assert Ok(re) = regexp.from_string("\\s+")
  regexp.replace(re, string.trim(s), " ")
}

fn truncate(s: String, n: Int) -> String {
  case string.length(s) > n {
    True -> string.trim(string.slice(s, 0, n)) <> "…"
    False -> s
  }
}

/// Serialize the annotation records to ./static/metadata/annotations.json as a
/// `{ route: { title, byline, abstract } }` object (gleam_json handles the
/// string escaping). static_dir copies it to /metadata/annotations.json.
fn write_annotations(
  annotations: List(#(String, Annotation)),
  metadata_dir: String,
) -> Result(Nil, String) {
  let obj =
    annotations
    |> list.map(fn(pair) {
      let #(route, a) = pair
      #(
        route,
        json.object([
          #("title", json.string(a.title)),
          #("byline", json.string(a.byline)),
          #("abstract", json.string(a.abstract)),
        ]),
      )
    })
    |> json.object
  let out = filepath.join(metadata_dir, "annotations.json")
  simplifile.write(to: out, contents: json.to_string(obj))
  |> result.map_error(fn(e) { "write " <> out <> ": " <> string.inspect(e) })
}

/// Shared publishability rule: a note is a real post (annotatable, linkable)
/// unless it is a draft, the About page, or a photo album.
fn is_publishable(
  path: String,
  entries: List(#(String, FieldValue)),
  cfg: config.VaultConfig,
) -> Bool {
  let is_draft = case get_scalar(entries, "draft") {
    Some(v) -> string.lowercase(string.trim(v)) == "true"
    None -> False
  }
  let is_about = filepath.base_name(path) == cfg.about_filename
  let is_photo = string.contains(path, cfg.photos_marker)
  !is_draft && !is_about && !is_photo
}

// --- Annotations: external (Wikipedia) providers ----------------------------

/// Read the external (URL-keyed) records from a previous annotations.json, to
/// reuse as a fetch cache. Internal (route-keyed) records are dropped — they are
/// rebuilt from source each run. A missing or unparseable file yields no cache.
fn read_external_cache(metadata_dir: String) -> Dict(String, Annotation) {
  let path = filepath.join(metadata_dir, "annotations.json")
  case simplifile.read(path) {
    Error(_) -> dict.new()
    Ok(raw) ->
      case json.parse(raw, decode.dict(decode.string, annotation_decoder())) {
        Ok(all) ->
          dict.filter(all, fn(key, _) { string.starts_with(key, "http") })
        Error(_) -> dict.new()
      }
  }
}

fn annotation_decoder() -> decode.Decoder(Annotation) {
  use title <- decode.field("title", decode.string)
  use byline <- decode.optional_field("byline", "", decode.string)
  use abstract <- decode.optional_field("abstract", "", decode.string)
  decode.success(Annotation(title:, byline:, abstract:))
}

/// Distinct external URLs in publishable post bodies that a provider recognizes.
fn collect_external_urls(
  files: List(String),
  cfg: config.VaultConfig,
) -> List(String) {
  files
  |> list.flat_map(fn(path) {
    case simplifile.read(path) {
      Error(_) -> []
      Ok(raw) -> {
        let extracted = frontmatter.extract(raw)
        let entries = case extracted.frontmatter {
          Some(fm) -> parse_frontmatter(fm)
          None -> []
        }
        case is_publishable(path, entries, cfg) {
          False -> []
          True ->
            mork_hrefs(extracted.content)
            |> list.filter(is_supported_external)
        }
      }
    }
  })
  |> list.unique
}

/// Whether some provider can annotate this external URL.
fn is_supported_external(url: String) -> Bool {
  wikipedia.is_wikipedia_url(url) || github.is_github_url(url)
}

/// Recognized external URLs in shared review-source notes (opt-in via
/// `share: true`). These feed the `/reviews` short cards, whose bodies are not in
/// md_files, so this is how their links get popup annotations.
fn collect_shared_review_urls(
  vault: String,
  cfg: config.VaultConfig,
) -> List(String) {
  cfg.review_sources
  |> list.flat_map(fn(source) {
    let dir = filepath.join(vault, source.dir)
    case simplifile.get_files(dir) {
      Error(_) -> []
      Ok(fs) ->
        fs
        |> list.filter(fn(p) {
          string.ends_with(p, ".md")
          && !string.starts_with(filepath.base_name(p), ".")
        })
        |> list.flat_map(fn(path) {
          case simplifile.read(path) {
            Error(_) -> []
            Ok(raw) -> {
              let extracted = frontmatter.extract(raw)
              let entries = case extracted.frontmatter {
                Some(fm) -> parse_frontmatter(fm)
                None -> []
              }
              let shared = case get_scalar(entries, "share") {
                Some(v) -> string.lowercase(string.trim(v)) == "true"
                None -> False
              }
              case shared {
                False -> []
                True ->
                  mork_hrefs(extracted.content)
                  |> list.filter(is_supported_external)
              }
            }
          }
        })
    }
  })
}

/// The href values mork produces when rendering `body` — the exact strings the
/// client matches against. Deriving keys from the render (not the raw markdown)
/// means mork's own URL transforms always agree with the rendered link's href:
/// it unescapes `\(` / `\)`, percent-encodes characters like `,` -> `%2C`, and
/// autolinks bare URLs. External links pass through the body transforms
/// unchanged, so rendering the raw body yields the same external hrefs.
pub fn mork_hrefs(body: String) -> List(String) {
  let html =
    mork.parse_with_options(
      options: mork.configure() |> mork.autolinks(True),
      input: body,
    )
    |> mork.to_html
  let assert Ok(re) = regexp.from_string("href=\"([^\"]+)\"")
  regexp.scan(re, html)
  |> list.filter_map(fn(m) {
    case m.submatches {
      [Some(href), ..] -> Ok(href)
      _ -> Error(Nil)
    }
  })
}

/// Resolve each referenced external URL to a record: reuse the cache, else fetch
/// via a provider. Unresolvable URLs are omitted (the link stays plain).
fn resolve_external(
  urls: List(String),
  cache: Dict(String, Annotation),
) -> List(#(String, Annotation)) {
  list.filter_map(urls, fn(url) {
    case dict.get(cache, url) {
      Ok(a) -> Ok(#(url, a))
      Error(_) ->
        case annotation_for_url(url) {
          Ok(a) -> {
            io.println("fetched annotation: " <> url)
            Ok(#(url, a))
          }
          Error(_) -> {
            io.println("WARN: no annotation for " <> url)
            Error(Nil)
          }
        }
    }
  })
}

/// Dispatch a URL to the first provider that recognizes it.
fn annotation_for_url(url: String) -> Result(Annotation, Nil) {
  case wikipedia.is_wikipedia_url(url), github.is_github_url(url) {
    True, _ -> wikipedia.fetch(url) |> result.map(wiki_annotation)
    _, True -> github.fetch(url) |> result.map(github_annotation)
    _, _ -> Error(Nil)
  }
}

/// Build a popup annotation from a Wikipedia summary. Byline names the source
/// (plus the page's short description when present); abstract is the extract.
fn wiki_annotation(s: wikipedia.Summary) -> Annotation {
  let byline = case string.trim(s.description) {
    "" -> "Wikipedia"
    d -> "Wikipedia · " <> d
  }
  Annotation(
    string.trim(s.title),
    byline,
    truncate(string.trim(s.extract), 300),
  )
}

/// Build a popup annotation from GitHub repo metadata. Byline names the source
/// plus language and star count; abstract is the repo description.
fn github_annotation(r: github.Repo) -> Annotation {
  let meta =
    [r.language, github_stars(r.stars)] |> list.filter(fn(s) { s != "" })
  let byline = string.join(["GitHub", ..meta], " · ")
  Annotation(
    string.trim(r.full_name),
    byline,
    truncate(string.trim(r.description), 300),
  )
}

fn github_stars(n: Int) -> String {
  case n {
    0 -> ""
    _ -> "★ " <> format_stars(n)
  }
}

/// Human star count: 900, 1.5k, 64k.
fn format_stars(n: Int) -> String {
  case n {
    _ if n >= 10_000 -> int.to_string({ n + 500 } / 1000) <> "k"
    _ if n >= 1000 ->
      int.to_string(n / 1000) <> "." <> int.to_string(n % 1000 / 100) <> "k"
    _ -> int.to_string(n)
  }
}

// --- Helpers ---

fn section_for(md_path: String, cfg: config.VaultConfig) -> Option(String) {
  case string.contains(md_path, cfg.reviews_marker) {
    True -> Some("reviews")
    False -> None
  }
}

fn build_attachment_index(dir: String) -> Dict(String, String) {
  case simplifile.get_files(dir) {
    Ok(files) ->
      list.fold(files, dict.new(), fn(acc, p) {
        dict.insert(acc, filepath.base_name(p), p)
      })
    Error(_) -> dict.new()
  }
}

fn ensure_dir(path: String) -> Result(Nil, String) {
  case simplifile.is_directory(path) {
    Ok(True) -> Ok(Nil)
    _ -> Error(path <> " is not a directory")
  }
}
