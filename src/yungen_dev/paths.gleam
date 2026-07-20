pub const content_dir = "./content"

pub const pages_dir = "./pages"

pub const static_dir = "./static"

pub const dist_dir = "./dist"

const covers_seg = "covers"

const photos_seg = "photos"

const metadata_seg = "metadata"

const reviews_seg = "reviews"

const about_file = "about.md"

pub fn covers_dir() -> String {
  static_dir <> "/" <> covers_seg
}

pub fn photos_dir() -> String {
  static_dir <> "/" <> photos_seg
}

pub fn metadata_dir() -> String {
  static_dir <> "/" <> metadata_seg
}

pub fn reviews_pages_dir() -> String {
  pages_dir <> "/" <> reviews_seg
}

pub fn photos_pages_dir() -> String {
  pages_dir <> "/" <> photos_seg
}

pub fn about_page() -> String {
  pages_dir <> "/" <> about_file
}

pub fn covers_url() -> String {
  "/" <> covers_seg
}

pub fn photos_url() -> String {
  "/" <> photos_seg
}
