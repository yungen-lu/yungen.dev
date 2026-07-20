import blogatto/dev
import blogatto/error
import gleam/io
import yungen_dev/blog

pub fn main() {
  case
    blog.config()
    |> dev.new()
    |> dev.start()
  {
    Ok(Nil) -> io.println("Dev server stopped.")
    Error(err) -> io.println("Dev server error: " <> error.describe_error(err))
  }
}
