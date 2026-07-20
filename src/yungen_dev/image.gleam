import gleam/list
import gleam/result
import gleam/string
import shellout
import simplifile

pub type Converter {
  Converter(vips: Bool)
}

pub fn detect() -> Converter {
  Converter(vips: available("vips", ["--version"]))
}

fn available(cmd: String, args: List(String)) -> Bool {
  shellout.command(run: cmd, with: args, in: ".", opt: []) |> result.is_ok
}

pub fn convertible(ext: String, c: Converter) -> Bool {
  case string.lowercase(ext) {
    "jpg" | "jpeg" | "png" | "gif" | "tif" | "tiff" | "heic" | "heif" -> c.vips
    _ -> False
  }
}

/// Place a source image at `dest`: convert to WebP when `dest` ends in `.webp`
/// (and the source is not already WebP), otherwise copy verbatim.
pub fn place(src: String, dest: String) -> Result(Nil, String) {
  case want_webp(src, dest) {
    True -> to_webp(src, dest)
    False ->
      simplifile.copy(src, dest)
      |> result.replace(Nil)
      |> result.map_error(fn(e) { "copy " <> src <> ": " <> string.inspect(e) })
  }
}

fn want_webp(src: String, dest: String) -> Bool {
  string.ends_with(string.lowercase(dest), ".webp")
  && !string.ends_with(string.lowercase(src), ".webp")
}

/// Convert `src` to a WebP at `dest` with vips. `keep=none` strips all metadata
/// (EXIF / GPS / camera info) from the published image; vips bakes the source
/// orientation into the pixels on load, so the result is upright. `[n=-1]` loads
/// every frame of an animated GIF so the WebP stays animated (a no-op for a
/// single-frame source).
fn to_webp(src: String, dest: String) -> Result(Nil, String) {
  let source = case ext_of(src) {
    "gif" -> src <> "[n=-1]"
    _ -> src
  }
  shellout.command(
    run: "vips",
    with: ["copy", source, dest <> "[keep=none]"],
    in: ".",
    opt: [],
  )
  |> result.replace(Nil)
  |> result.map_error(fn(e) { "vips " <> src <> ": " <> e.1 })
}

fn ext_of(name: String) -> String {
  case list.reverse(string.split(name, ".")) {
    [ext, ..] -> string.lowercase(ext)
    _ -> ""
  }
}
