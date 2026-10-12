#!/usr/bin/env python3
"""Verifies a built Beloved site folder. Exits 1 with a list of problems.

    python3 website/check.py website/public [--production]

Checks every HTML page for: resolvable internal links, anchors and assets; title,
description, Open Graph and Twitter metadata; no scripts, inline styles, forms or
mixed content; no placeholder, local or personal values; required pages and files.
--production additionally requires canonical HTTPS URLs, an indexable robots.txt
with a sitemap whose URLs map to real pages, and no preview markers.
"""
import os
import re
import sys
from html.parser import HTMLParser
from urllib.parse import urlparse

REQUIRED_FILES = ["index.html", "faq.html", "support.html", "privacy.html", "terms.html", "404.html",
                  "robots.txt", "_headers", "assets/site.css", "assets/favicon-32.png",
                  "assets/apple-touch-icon.png", "assets/icon-512.png", "assets/icon-64.png"]
LEGAL_LINKS = ["privacy.html", "terms.html", "support.html"]
FORBIDDEN = re.compile(r"lorem ipsum|coming soon|under construction|TODO|FIXME|localhost|127\.0\.0\.1|"
                       r"example\.com|your-domain|/Users/|file://", re.I)


class Page(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links, self.ids, self.meta, self.tags = [], set(), {}, []
        self.title, self.in_title, self.canonical = "", False, None

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        self.tags.append(tag)
        if "id" in attrs:
            self.ids.add(attrs["id"])
        for key in ("href", "src"):
            if attrs.get(key):
                self.links.append((tag, attrs[key]))
        if tag == "meta":
            name = attrs.get("name") or attrs.get("property")
            if name:
                self.meta[name] = attrs.get("content", "")
        if tag == "link" and attrs.get("rel") == "canonical":
            self.canonical = attrs.get("href")
        if tag == "title":
            self.in_title = True
        if "style" in attrs:
            self.tags.append("inline-style")

    def handle_endtag(self, tag):
        if tag == "title":
            self.in_title = False

    def handle_data(self, data):
        if self.in_title:
            self.title += data


def check(folder, production):
    problems = []
    for name in REQUIRED_FILES:
        if not os.path.exists(os.path.join(folder, name)):
            problems.append(f"missing file: {name}")
    pages = {}
    for name in sorted(os.listdir(folder)):
        if name.endswith(".html"):
            parser = Page()
            with open(os.path.join(folder, name), encoding="utf-8") as handle:
                text = handle.read()
            parser.feed(text)
            pages[name] = (parser, text)

    for name, (page, text) in pages.items():
        where = f"{name}:"
        if page.tags.count("h1") != 1:
            problems.append(f"{where} has {page.tags.count('h1')} <h1> elements (expected 1)")
        if not page.title.strip():
            problems.append(f"{where} empty <title>")
        for key in ("description", "og:title", "og:description", "og:image", "twitter:card"):
            if not page.meta.get(key):
                problems.append(f"{where} missing meta {key}")
        for tag in ("script", "form", "iframe", "inline-style", "style"):
            if tag in page.tags:
                problems.append(f"{where} contains <{tag}> (CSP allows none)")
        if "http://" in text.replace("http://www.sitemaps.org", ""):
            problems.append(f"{where} insecure http:// reference")
        match = FORBIDDEN.search(text)
        if match:
            problems.append(f"{where} forbidden text {match.group(0)!r}")
        for link in LEGAL_LINKS:
            if f'href="{link}"' not in text:
                problems.append(f"{where} no link to {link}")
        for tag, url in page.links:
            parsed = urlparse(url)
            if parsed.scheme in ("http", "https", "mailto"):
                if parsed.scheme == "https" and parsed.hostname and production and tag == "a":
                    pass  # external links (App Store) are validated by build.py
                continue
            target, _, anchor = url.partition("#")
            target = target or name
            if not os.path.exists(os.path.join(folder, target)):
                problems.append(f"{where} broken link {url}")
            elif anchor and target in pages and anchor not in pages[target][0].ids:
                problems.append(f"{where} missing anchor {url}")
        if production:
            if 'class="preview"' in text or 'class="gap"' in text:
                problems.append(f"{where} preview markers in a production build")
            if name != "404.html":
                if not page.canonical or not page.canonical.startswith("https://"):
                    problems.append(f"{where} missing https canonical URL")
                if "noindex" in page.meta.get("robots", ""):
                    problems.append(f"{where} noindex in a production build")
            if not page.meta.get("og:image", "").startswith("https://"):
                problems.append(f"{where} og:image must be an absolute https URL")

    robots_path = os.path.join(folder, "robots.txt")
    robots = open(robots_path, encoding="utf-8").read() if os.path.exists(robots_path) else ""
    sitemap = os.path.join(folder, "sitemap.xml")
    if production:
        if "Disallow: /\n" in robots or "Sitemap: https://" not in robots:
            problems.append("robots.txt must allow crawling and name the https sitemap")
        if not os.path.exists(sitemap):
            problems.append("missing sitemap.xml")
        else:
            for loc in re.findall(r"<loc>([^<]+)</loc>", open(sitemap, encoding="utf-8").read()):
                path = urlparse(loc).path.lstrip("/") or "index.html"
                if path not in pages and path + ".html" in pages:
                    path += ".html"  # clean URLs (Cloudflare Pages)
                if not loc.startswith("https://") or path not in pages:
                    problems.append(f"sitemap entry has no page: {loc}")
    elif "Disallow: /" not in robots:
        problems.append("preview robots.txt must disallow crawling")
    return problems


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if len(args) != 1:
        sys.exit(__doc__)
    problems = check(args[0], "--production" in sys.argv)
    for problem in problems:
        print("FAIL", problem)
    if problems:
        return 1
    print(f"site check passed ({'production' if '--production' in sys.argv else 'preview'})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
