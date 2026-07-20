//// yungen.dev — build entrypoint.
////
//// Builds the static site into ./dist. Run with `gleam run`.
//// For the live-reload dev server, run `gleam run -m yungen_dev/dev`.

import blogatto
import blogatto/error
import gleam/io
import yungen_dev/blog

pub fn main() {
  case blogatto.build(blog.config()) {
    Ok(Nil) -> io.println("Site built successfully in ./dist")
    Error(err) -> io.println("Build failed: " <> error.describe_error(err))
  }
}
