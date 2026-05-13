#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["python-frontmatter>=1.1"]
# ///
"""Sync Obsidian vault notes into the Hugo content/ tree.

Routes:
  Notes/Blog/About.md         -> content/about/index.md
  Notes/Blog/Reviews/*.md     -> content/reviews/<slug>/index.md
  Notes/Blog/*.md             -> content/blog/<slug>/index.md

Per-file transforms:
  - skip if frontmatter `draft: true`
  - drop Obsidian-only `type` key (collides with Hugo's reserved `type`)
  - drop frontmatter keys whose value is None
  - convert `![[name.ext]]` / `![[name.ext|modifier]]` embeds to `![](slug.ext)`
    and copy the referenced file from <vault>/Attachments/** into the page bundle

Usage: sync_from_vault.py <vault_dir> <content_dir>
"""

from __future__ import annotations

import argparse
import re
import shutil
import sys
from pathlib import Path

import frontmatter

EMBED_RE = re.compile(r"!\[\[([^\]|]+)(?:\|[^\]]*)?\]\]")
APOSTROPHES = re.compile(r"['‘’`]")
NON_SLUG = re.compile(r"[^a-z0-9]+")


def slugify(text: str) -> str:
    text = APOSTROPHES.sub("", text.lower())
    return NON_SLUG.sub("-", text).strip("-")


def slugify_filename(filename: str) -> str:
    stem, dot, ext = filename.rpartition(".")
    if not dot:
        return slugify(filename)
    return f"{slugify(stem)}.{ext.lower()}"


def find_attachment(name: str, attachments_dir: Path) -> Path | None:
    for path in attachments_dir.rglob(name):
        if path.is_file():
            return path
    return None


def clean_output(content_dir: Path) -> None:
    """Remove generated content but preserve hand-maintained _index.md stubs."""
    for section in ("blog", "reviews"):
        section_dir = content_dir / section
        if not section_dir.exists():
            continue
        for item in section_dir.iterdir():
            if item.name == "_index.md":
                continue
            if item.is_dir():
                shutil.rmtree(item)
            else:
                item.unlink()
    about_dir = content_dir / "about"
    if about_dir.is_dir():
        shutil.rmtree(about_dir)
    legacy_about = content_dir / "about.md"
    if legacy_about.exists():
        legacy_about.unlink()


def route(md_path: Path, blog_root: Path) -> tuple[str, str | None]:
    rel = md_path.relative_to(blog_root)
    parts = rel.parts
    if parts == ("About.md",):
        return "about", None
    if parts[0] == "Reviews":
        return "reviews", slugify(md_path.stem)
    return "blog", slugify(md_path.stem)


def process(md_path: Path, blog_root: Path, content_dir: Path, attachments_dir: Path) -> None:
    section, slug = route(md_path, blog_root)
    post = frontmatter.load(md_path)

    if post.metadata.get("draft"):
        return

    post.metadata.pop("type", None)
    post.metadata = {k: v for k, v in post.metadata.items() if v is not None}

    pending: list[tuple[str, str]] = []

    def replace_embed(match: re.Match[str]) -> str:
        original = match.group(1).strip()
        new_name = slugify_filename(original)
        pending.append((original, new_name))
        return f"![]({new_name})"

    post.content = EMBED_RE.sub(replace_embed, post.content)

    out_dir = content_dir / "about" if section == "about" else content_dir / section / slug
    out_dir.mkdir(parents=True, exist_ok=True)
    out_md = out_dir / "index.md"

    with out_md.open("wb") as f:
        frontmatter.dump(post, f, sort_keys=False, allow_unicode=True)

    for original, new_name in pending:
        src = find_attachment(original, attachments_dir)
        if src is None:
            print(
                f"WARN: attachment '{original}' referenced by {md_path.name} not found",
                file=sys.stderr,
            )
            continue
        shutil.copy2(src, out_dir / new_name)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("vault_dir", type=Path, help="Path to the Obsidian vault root")
    ap.add_argument("content_dir", type=Path, help="Path to the Hugo content/ directory")
    args = ap.parse_args()

    blog_root = args.vault_dir / "Notes" / "Blog"
    attachments_dir = args.vault_dir / "Attachments"
    if not blog_root.is_dir():
        ap.error(f"{blog_root} is not a directory")
    if not attachments_dir.is_dir():
        ap.error(f"{attachments_dir} is not a directory")

    clean_output(args.content_dir)
    for md in sorted(blog_root.rglob("*.md")):
        if md.name.startswith("."):
            continue
        process(md, blog_root, args.content_dir, attachments_dir)
    return 0


if __name__ == "__main__":
    sys.exit(main())
