pub type ReviewSource {
  ReviewSource(medium: String, dir: String)
}

pub type VaultConfig {
  VaultConfig(
    blog_dir: String,
    attachments_dir: String,
    about_filename: String,
    photos_marker: String,
    reviews_marker: String,
    review_sources: List(ReviewSource),
  )
}

pub fn default() -> VaultConfig {
  VaultConfig(
    blog_dir: "Notes/Blog",
    attachments_dir: "Attachments",
    about_filename: "About.md",
    photos_marker: "/Photos/",
    reviews_marker: "/Reviews/",
    review_sources: [
      ReviewSource("film", "Notes/Movies"),
      ReviewSource("anime", "Notes/Anime"),
      ReviewSource("book", "Notes/Books"),
    ],
  )
}
