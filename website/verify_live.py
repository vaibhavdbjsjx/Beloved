#!/usr/bin/env python3
"""Checks a deployed Beloved website. Read-only: it only sends GET requests to your site.

    python3 website/verify_live.py https://<your-domain> [--clean-urls]

Verifies each page answers 200 over HTTPS with HTML, is actually a Beloved page (not a parked
domain), carries the security headers from _headers (plus HSTS), contains no preview markers, that robots.txt and sitemap.xml are served, that a
missing page returns 404, and that plain http:// redirects to https://. An unreachable site (DNS, TLS, refused connection, timeout) is reported as a failure.
Exits 1 on any problem.
"""
import sys
import urllib.error
import urllib.request

PAGES = ["", "faq.html", "support.html", "privacy.html", "terms.html"]
HEADERS = ["content-security-policy", "x-content-type-options", "referrer-policy"]


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


def fetch(url, follow=True):
    opener = urllib.request.build_opener() if follow else urllib.request.build_opener(NoRedirect)
    request = urllib.request.Request(url, headers={"User-Agent": "beloved-verify-live/1"})
    try:
        with opener.open(request, timeout=15) as response:
            return response.status, {k.lower(): v for k, v in response.headers.items()}, response.read().decode("utf-8", "replace"), response.url
    except urllib.error.HTTPError as error:
        return error.code, {k.lower(): v for k, v in error.headers.items()}, "", url
    except (urllib.error.URLError, OSError) as error:
        # DNS failure, refused connection, TLS error, timeout: never treated as success.
        reason = getattr(error, "reason", error)
        return 0, {}, f"unreachable: {reason}", url


def verify(base, clean_urls=False, check_http_redirect=True):
    base = base.rstrip("/")
    problems = []
    if not base.startswith("https://") and not base.startswith("http://127.0.0.1") and not base.startswith("http://localhost"):
        return ["base URL must start with https://"]
    for page in PAGES:
        path = page[:-5] if clean_urls and page.endswith(".html") else page
        url = f"{base}/{path}"
        status, headers, body, _ = fetch(url)
        if status == 0:
            problems.append(f"{url}: {body}")
            return problems  # the site can't be reached; further checks would only repeat this
        if status != 200:
            problems.append(f"{url}: HTTP {status}")
            continue
        if "text/html" not in headers.get("content-type", ""):
            problems.append(f"{url}: content-type {headers.get('content-type')!r}")
        if '<meta property="og:site_name" content="Beloved">' not in body:
            problems.append(f"{url}: not a Beloved page (parked domain or wrong site?)")
        for header in HEADERS + (["strict-transport-security"] if base.startswith("https://") else []):
            if header not in headers:
                problems.append(f"{url}: missing {header} header")
        if 'class="preview"' in body or 'class="gap"' in body or 'content="noindex"' in body:
            problems.append(f"{url}: preview build was deployed")
    for path in ("robots.txt", "sitemap.xml", "assets/site.css", "assets/icon-512.png"):
        status, _, _, _ = fetch(f"{base}/{path}")
        if status != 200:
            problems.append(f"{base}/{path}: HTTP {status}")
    status, _, body, _ = fetch(f"{base}/this-page-does-not-exist-404-check")
    if status != 404:
        problems.append(f"missing pages return HTTP {status}, expected 404")
    if check_http_redirect and base.startswith("https://"):
        status, headers, _, _ = fetch("http://" + base[len("https://"):] + "/", follow=False)
        if status not in (301, 302, 307, 308) or not headers.get("location", "").startswith("https://"):
            problems.append(f"http:// does not redirect to https:// (HTTP {status})")
    return problems


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if len(args) != 1:
        sys.exit(__doc__)
    problems = verify(args[0], clean_urls="--clean-urls" in sys.argv)
    for problem in problems:
        print("FAIL", problem)
    if problems:
        return 1
    print(f"live site check passed: {args[0]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
