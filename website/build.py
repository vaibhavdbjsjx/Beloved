#!/usr/bin/env python3
"""Builds Beloved's public website as static HTML (no JavaScript, no third-party requests).

Pages: home, FAQ, support, privacy policy, terms of use, 404 — plus robots.txt,
sitemap.xml, security headers (_headers), a stylesheet and icons. The privacy policy is
generated from the file the app bundles (App/PrayerLock/Resources/Legal/PrivacyPolicy.md),
so the App Store link and the in-app copy can never drift apart.

Owner/legal values come from a JSON config (see website/site.example.json). Nothing is
invented: a production build refuses to run until real values are supplied, and every
build is checked by website/check.py before it is reported as written.

    # Production (all required values present and real):
    python3 website/build.py --config website/site.json

    # Local preview (missing or example values are highlighted; pages are noindex):
    python3 website/build.py --config website/site.example.json --preview

    # Hosted build (Netlify / Cloudflare Pages): values from BELOVED_* environment variables
    python3 website/build.py --config-env
"""
import argparse
import datetime
import html
import json
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WEBSITE = os.path.join(ROOT, "website")
POLICY = os.path.join(ROOT, "App", "PrayerLock", "Resources", "Legal", "PrivacyPolicy.md")
TERMS = os.path.join(WEBSITE, "content", "terms.md")
ICON = os.path.join(ROOT, "App", "PrayerLock", "Resources", "Assets.xcassets", "AppIcon.appiconset", "AppIcon-1024.png")
# Icons are generated once on macOS (--refresh-icons) and committed, so hosted Linux builds
# are deterministic and need no image tools.
STATIC_ASSETS = os.path.join(WEBSITE, "static", "assets")
ICON_SIZES = [("icon-512.png", 512), ("apple-touch-icon.png", 180), ("icon-64.png", 64), ("favicon-32.png", 32)]
SHARED_XCCONFIG = os.path.join(ROOT, "Config", "Shared.xcconfig")
EMAIL = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
APP_STORE = re.compile(r"^https://apps\.apple\.com/[a-z]{2}/app/[^/]+/id\d+/?$")
# Values that must never reach a production build (RFC 2606 names and template text).
EXAMPLE = re.compile(r"(\.example\b|example\.(com|org|net)|your-domain|EXAMPLE|REPLACE|localhost|127\.0\.0\.1)", re.I)
BRAND = "Beloved"
DESCRIPTION = ("Beloved places a gentle pause in front of the apps you choose and offers a short "
               "moment of prayer, scripture, a mantra, a dua or a reflection before you continue.")

REQUIRED = {
    "domain": "production domain (https://…)",
    "support_email": "support e-mail address",
    "legal_name": "legal name of the developer or company",
    "terms_effective_date": "Terms of Use effective date",
}
OPTIONAL = ["contact_address", "app_store_url", "governing_law"]
FLAGS = ["clean_urls"]
ENV_PREFIX = "BELOVED_"


# ---------------------------------------------------------------- configuration

def is_example(text):
    return bool(text) and bool(EXAMPLE.search(text))


def raw_config(path):
    """From a JSON file, or (path None) from BELOVED_<KEY> environment variables."""
    if path:
        with open(path, encoding="utf-8") as handle:
            return json.load(handle)
    return {key: os.environ.get(ENV_PREFIX + key.upper(), "") for key in list(REQUIRED) + OPTIONAL + FLAGS}


def load_config(path, preview):
    raw = raw_config(path)
    config = {key: str(raw.get(key) or "").strip() for key in list(REQUIRED) + OPTIONAL}
    # Cloudflare Pages serves /privacy for privacy.html (and redirects the .html form), so
    # canonical URLs and the sitemap must use the clean form there.
    config["clean_urls"] = str(raw.get("clean_urls", "")).strip().lower() in ("1", "true", "yes")
    problems = []
    if config["domain"] and not re.match(r"^https://[a-z0-9.-]+\.[a-z]{2,}$", config["domain"].rstrip("/"), re.I):
        problems.append("domain must be https://<host> with no path")
    if config["support_email"] and not EMAIL.match(config["support_email"]):
        problems.append("support_email is not an e-mail address")
    if config["app_store_url"] and not APP_STORE.match(config["app_store_url"]):
        problems.append("app_store_url must be the real https://apps.apple.com/<country>/app/<name>/id<number> link")
    if problems:
        sys.exit("Invalid config:\n  " + "\n  ".join(problems))
    if not preview:
        missing = [label for key, label in REQUIRED.items() if not config[key]]
        examples = [key for key in list(REQUIRED) + OPTIONAL if is_example(config[key])]
        if missing or examples:
            lines = [f"missing: {label}" for label in missing] + [f"example/placeholder value: {key}" for key in examples]
            sys.exit("Production build refused (use --preview to look at the site):\n  " + "\n  ".join(lines))
    config["domain"] = config["domain"].rstrip("/")
    return config


def configured(config, key):
    """True when a value is real enough to show as-is."""
    return bool(config[key]) and not is_example(config[key])


def value(config, key):
    """The configured value, or a visible gap marker (preview builds only)."""
    if configured(config, key):
        return html.escape(config[key])
    label = REQUIRED.get(key, key.replace("_", " "))
    return f'<mark class="gap">[{html.escape(label)} — not configured]</mark>'


def minimum_ios():
    """Deployment target from the Xcode config, so the site can't drift from the app."""
    with open(SHARED_XCCONFIG, encoding="utf-8") as handle:
        match = re.search(r"^IPHONEOS_DEPLOYMENT_TARGET\s*=\s*([0-9.]+)", handle.read(), re.M)
    if not match:
        sys.exit("IPHONEOS_DEPLOYMENT_TARGET not found in Config/Shared.xcconfig")
    return re.sub(r"\.0$", "", match.group(1))


# ---------------------------------------------------------------- markdown

def inline(text):
    escaped = html.escape(text, quote=False)
    escaped = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", escaped)
    return re.sub(r"\*(.+?)\*", r"<em>\1</em>", escaped)


def markdown_to_html(markdown, tokens=None):
    out, paragraph, in_list = [], [], False

    def close_paragraph():
        if paragraph:
            out.append("<p>" + inline(" ".join(paragraph)) + "</p>")
            paragraph.clear()

    def close_list():
        nonlocal in_list
        if in_list:
            out.append("</ul>")
            in_list = False

    for raw in markdown.splitlines():
        line = raw.strip()
        if not line:
            close_paragraph(); close_list()
        elif line.startswith("## "):
            close_paragraph(); close_list(); out.append("<h2>" + inline(line[3:]) + "</h2>")
        elif line.startswith("# "):
            close_paragraph(); close_list(); out.append("<h1>" + inline(line[2:]) + "</h1>")
        elif line.startswith("- "):
            close_paragraph()
            if not in_list:
                out.append("<ul>"); in_list = True
            out.append("<li>" + inline(line[2:]) + "</li>")
        else:
            close_list(); paragraph.append(line)
    close_paragraph(); close_list()
    result = "\n".join(out)
    # Tokens are substituted after escaping, so pre-escaped HTML (gap markers) survives.
    for key, replacement in (tokens or {}).items():
        result = result.replace("{{" + key + "}}", replacement)
    leftover = re.findall(r"\{\{[A-Z_]+\}\}", result)
    if leftover:
        sys.exit(f"Unreplaced template tokens: {sorted(set(leftover))}")
    return result


# ---------------------------------------------------------------- layout

STYLE = """:root{color-scheme:light;
--bg:#FFFFFF;--soft:#F6F7F9;--soft2:#EEF1F6;--ink:#0B0D12;--ink2:#5B616E;--ink3:#8A909C;--line:#E6E8EC;
--accent:#243B7F;--accent-hover:#1B2E66;--accent-tint:#EEF2FB;--ok:#1F7A4D;--no:#9A3B32;
--radius:20px;--shadow:0 1px 2px rgba(16,24,40,.04),0 8px 24px rgba(16,24,40,.06);
--font:-apple-system,BlinkMacSystemFont,"SF Pro Text","Segoe UI",Roboto,"Helvetica Neue",Arial,sans-serif;
--display:-apple-system,BlinkMacSystemFont,"SF Pro Display","Segoe UI",Roboto,"Helvetica Neue",Arial,sans-serif}
*{box-sizing:border-box}
html{-webkit-text-size-adjust:100%;scroll-behavior:smooth}
@media(prefers-reduced-motion:reduce){html{scroll-behavior:auto}}
body{margin:0;background:var(--bg);color:var(--ink);font:400 1.0625rem/1.6 var(--font);-webkit-font-smoothing:antialiased}
img,svg{display:block;max-width:100%}
a{color:var(--accent);text-decoration:none}
a:hover{text-decoration:underline;text-underline-offset:.2em}
a:focus-visible,summary:focus-visible{outline:3px solid var(--accent);outline-offset:3px;border-radius:8px}
p{margin:0 0 1rem}
.skip{position:absolute;left:-999px}.skip:focus{left:1rem;top:1rem;background:#fff;padding:.6rem 1rem;border-radius:10px;box-shadow:var(--shadow);z-index:20}
.wrap{max-width:72rem;margin:0 auto;padding:0 1.5rem}
.narrow{max-width:46rem}
.preview{background:#7A2E2E;color:#fff;text-align:center;padding:.5rem 1rem;font-size:.9rem;font-weight:600}
mark.gap{background:#FFE7B3;color:#4A3200;padding:0 .3em;border-radius:4px}

/* header */
header.site{position:sticky;top:0;z-index:10;background:rgba(255,255,255,.86);-webkit-backdrop-filter:saturate(180%) blur(16px);backdrop-filter:saturate(180%) blur(16px);border-bottom:1px solid var(--line)}
header.site .wrap{display:flex;align-items:center;gap:.5rem 2rem;min-height:4rem;flex-wrap:wrap}
.brand{display:flex;align-items:center;gap:.6rem;font:650 1.15rem var(--display);letter-spacing:-.01em;color:var(--ink);min-height:44px}
.brand:hover{text-decoration:none}
.brand img{width:30px;height:30px;border-radius:8px}
nav.main{margin-left:auto}
nav.main ul{list-style:none;display:flex;gap:.1rem 1.6rem;margin:0;padding:0;flex-wrap:wrap}
nav.main a{color:var(--ink2);font-size:.95rem;display:inline-flex;align-items:center;min-height:44px}
nav.main a:hover,nav.main a[aria-current]{color:var(--ink);text-decoration:none}
nav.main a[aria-current]{font-weight:600}
@media(max-width:40rem){header.site{position:static}header.site .wrap{padding-top:.4rem;padding-bottom:.2rem}nav.main{margin-left:0;width:100%}nav.main ul{gap:0 1.2rem}}

/* type */
h1,h2,h3{font-family:var(--display);color:var(--ink);letter-spacing:-.025em;line-height:1.08;margin:0}
h1{font-size:clamp(2.6rem,6.2vw,4.5rem);font-weight:700;letter-spacing:-.035em}
h2{font-size:clamp(2rem,4vw,3rem);font-weight:700}
h3{font-size:1.2rem;font-weight:650;letter-spacing:-.01em;line-height:1.3}
.lede{font-size:clamp(1.15rem,1.6vw,1.35rem);color:var(--ink2);line-height:1.55;max-width:34rem;margin-top:1.25rem}
.kicker{display:inline-flex;align-items:center;gap:.5rem;font-size:.85rem;font-weight:600;color:var(--accent);background:var(--accent-tint);padding:.35rem .8rem;border-radius:999px;margin-bottom:1.5rem}
.section-head{max-width:40rem;margin-bottom:3rem}
.section-head p{color:var(--ink2);font-size:1.15rem;margin-top:1rem}
.center{text-align:center;margin-left:auto;margin-right:auto}
.muted{color:var(--ink2)}
.visually-hidden{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0);white-space:nowrap}

/* buttons */
.actions{display:flex;gap:.75rem;flex-wrap:wrap;margin-top:2rem}
.center .actions{justify-content:center}
.button{display:inline-flex;align-items:center;justify-content:center;gap:.5rem;min-height:48px;padding:0 1.5rem;border-radius:999px;font-weight:600;font-size:1rem;background:var(--accent);color:#fff;transition:background .15s}
.button:hover{background:var(--accent-hover);text-decoration:none}
.button.secondary{background:var(--soft);color:var(--ink)}
.button.secondary:hover{background:var(--soft2)}
.notice{margin-top:1.25rem;font-size:.92rem;color:var(--ink3)}

/* hero */
.hero{display:grid;gap:3.5rem;align-items:center;padding:5.5rem 0 5rem}
@media(min-width:56rem){.hero{grid-template-columns:1.15fr .85fr}}
.trust{list-style:none;display:flex;flex-wrap:wrap;gap:.6rem 1.5rem;padding:0;margin:2.25rem 0 0;color:var(--ink2);font-size:.95rem}
.trust li{display:flex;align-items:center;gap:.45rem}
.trust svg{width:18px;height:18px;color:var(--ok)}

/* phone illustration (real app copy, drawn in HTML) */
figure.device{margin:0;justify-self:center;text-align:center}
.phone{width:290px;max-width:78vw;aspect-ratio:9/19.2;border-radius:48px;background:#0B0D12;padding:11px;box-shadow:0 30px 60px -20px rgba(16,24,40,.35),0 0 0 1px rgba(16,24,40,.08)}
.screen{height:100%;border-radius:38px;background:linear-gradient(180deg,#F4F6FB 0%,#FFFFFF 55%);display:flex;flex-direction:column;align-items:center;justify-content:center;padding:2rem 1.4rem;text-align:center;position:relative}
.screen::before{content:"";position:absolute;top:10px;left:50%;transform:translateX(-50%);width:34%;height:26px;border-radius:999px;background:#0B0D12}
.screen img{width:68px;height:68px;border-radius:16px;margin-bottom:1.25rem;box-shadow:0 8px 20px rgba(47,74,138,.25)}
.screen .s-title{font:650 1.12rem/1.3 var(--display);color:var(--ink);letter-spacing:-.01em}
.screen .s-sub{font-size:.88rem;color:var(--ink2);margin:.5rem 0 1.75rem;line-height:1.45}
.screen .s-primary{width:100%;background:var(--accent);color:#fff;border-radius:14px;padding:.75rem;font-weight:600;font-size:.95rem}
.screen .s-secondary{margin-top:.8rem;color:var(--accent);font-weight:600;font-size:.95rem}
.screen.moment{justify-content:flex-start;padding-top:4.5rem;text-align:left;align-items:flex-start}
.screen.moment .s-title{font-size:1.25rem}
.screen.moment .s-sub{margin-bottom:auto}
.screen.moment .s-primary{text-align:center}
figcaption{font-size:.8rem;color:var(--ink3);margin-top:1rem}

/* sections */
section.band{padding:6rem 0}
section.band.soft{background:var(--soft)}
.strip{border-top:1px solid var(--line);border-bottom:1px solid var(--line);padding:2rem 0}
.strip ul{list-style:none;margin:0;padding:0;display:grid;gap:1.25rem;grid-template-columns:repeat(auto-fit,minmax(min(13rem,100%),1fr))}
.strip li{display:flex;gap:.8rem;align-items:flex-start}
.strip strong{display:block;font-weight:600}
.strip span{color:var(--ink2);font-size:.92rem}
.icon{flex:none;width:40px;height:40px;border-radius:12px;background:var(--accent-tint);color:var(--accent);display:grid;place-items:center}
.icon svg{width:21px;height:21px}

/* steps */
.steps{display:grid;gap:3rem;align-items:center}
@media(min-width:56rem){.steps{grid-template-columns:1fr .8fr}}
ol.step-list{list-style:none;margin:0;padding:0;display:grid;gap:1.25rem}
ol.step-list li{display:grid;grid-template-columns:auto 1fr;gap:1.1rem;background:#fff;border:1px solid var(--line);border-radius:var(--radius);padding:1.5rem}
.num{width:36px;height:36px;border-radius:50%;background:var(--ink);color:#fff;display:grid;place-items:center;font-weight:700;font-size:.95rem}
ol.step-list p{margin:.35rem 0 0;color:var(--ink2)}

/* cards */
.grid{display:grid;gap:1.25rem;grid-template-columns:repeat(auto-fit,minmax(min(17rem,100%),1fr))}
.card{background:#fff;border:1px solid var(--line);border-radius:var(--radius);padding:1.75rem;transition:box-shadow .2s,transform .2s}
.card:hover{box-shadow:var(--shadow)}
@media(prefers-reduced-motion:no-preference){.card:hover{transform:translateY(-2px)}}
.card .icon{margin-bottom:1.25rem}
.card p{color:var(--ink2);margin:.5rem 0 0}
.two{display:grid;gap:1.25rem}
@media(min-width:48rem){.two{grid-template-columns:1fr 1fr}}
.panel{background:#fff;border:1px solid var(--line);border-radius:var(--radius);padding:2rem}
.panel h3{margin-bottom:1.25rem;font-size:1.3rem}
ul.checks{list-style:none;margin:0;padding:0;display:grid;gap:.9rem}
ul.checks li{display:grid;grid-template-columns:22px 1fr;gap:.75rem;color:var(--ink2)}
ul.checks svg{width:20px;height:20px;margin-top:.2rem}
ul.checks.yes svg{color:var(--ok)}
ul.checks.no svg{color:var(--no)}
.chips{display:flex;flex-wrap:wrap;gap:.6rem;margin-top:2rem}
.chips span{border:1px solid var(--line);background:#fff;border-radius:999px;padding:.55rem 1rem;font-weight:500}
.chips span small{color:var(--ink3);font-weight:400;margin-left:.35rem}
blockquote.why{margin:0;font:600 clamp(1.6rem,3.2vw,2.4rem)/1.3 var(--display);letter-spacing:-.02em;color:var(--ink)}
.cta{background:var(--ink);color:#fff;border-radius:32px;padding:4.5rem 2rem;text-align:center}
.cta h2{color:#fff}
.cta p{color:#B8BDC8;font-size:1.15rem;margin:1rem auto 0;max-width:34rem}
.cta .button{background:#fff;color:var(--ink)}
.cta .button:hover{background:#E9ECF2}
.cta .button.secondary{background:rgba(255,255,255,.12);color:#fff}

/* document pages */
.page-head{background:var(--soft);border-bottom:1px solid var(--line);padding:4.5rem 0 3.5rem}
.page-head h1{font-size:clamp(2.2rem,5vw,3.4rem)}
.page-head p{color:var(--ink2);font-size:1.15rem;margin:1rem 0 0;max-width:38rem}
.doc-body{padding:3.5rem 0 5rem}
.prose h1{display:none}
.prose h2{font-size:1.5rem;margin:2.75rem 0 .9rem;letter-spacing:-.015em}
.prose h2:first-child{margin-top:0}
.prose p,.prose li{color:#2B2F38}
.prose ul{padding-left:1.25rem;margin:0 0 1rem}
.prose li{margin:.4rem 0}
.prose strong{color:var(--ink)}
.faq-list{display:grid;gap:.75rem}
details{background:#fff;border:1px solid var(--line);border-radius:16px;padding:0 1.4rem;transition:box-shadow .2s}
details[open]{box-shadow:var(--shadow)}
summary{list-style:none;cursor:pointer;font-weight:600;font-size:1.05rem;min-height:60px;display:flex;align-items:center;justify-content:space-between;gap:1rem}
summary::-webkit-details-marker{display:none}
summary::after{content:"+";font-size:1.5rem;font-weight:300;color:var(--ink3)}
details[open] summary::after{content:"\\2212"}
details p{color:var(--ink2);margin:0 0 1.1rem}
.help-grid{display:grid;gap:1.25rem;grid-template-columns:repeat(auto-fit,minmax(min(18rem,100%),1fr));margin-bottom:3rem}
.help-grid .panel h2{font-size:1.25rem;margin:0 0 1rem}
.help-grid ul{margin:0;padding-left:1.15rem;color:var(--ink2)}
.help-grid li{margin:.45rem 0}
.contact-card{background:var(--soft);border-radius:var(--radius);padding:2.25rem}
.contact-card h2{font-size:1.6rem;margin-bottom:.75rem}

/* footer */
footer.site{border-top:1px solid var(--line);padding:4rem 0 3rem;color:var(--ink2);font-size:.92rem}
.foot{display:grid;gap:2rem;grid-template-columns:repeat(auto-fit,minmax(min(10rem,100%),1fr));margin-bottom:2.5rem}
.foot h2{font:600 .8rem var(--font);letter-spacing:.06em;text-transform:uppercase;color:var(--ink3);margin-bottom:.75rem}
.foot ul{list-style:none;margin:0;padding:0}
.foot a{color:var(--ink2);display:inline-flex;align-items:center;min-height:36px}
.foot a:hover{color:var(--ink)}
.foot .brand{margin-bottom:.5rem}
.legal{border-top:1px solid var(--line);padding-top:1.5rem;display:grid;gap:.4rem;color:var(--ink3);font-size:.85rem}
.legal p{margin:0}
@media(max-width:40rem){.wrap{padding:0 1.15rem}.hero{padding:3rem 0 3.5rem;gap:2.5rem}section.band{padding:4rem 0}
.section-head{margin-bottom:2rem}.panel,.card{padding:1.4rem}.cta{padding:3rem 1.25rem;border-radius:24px}
.page-head{padding:3rem 0 2.5rem}.contact-card{padding:1.5rem}}
@media print{header.site,footer.site .foot,.skip,.preview{display:none}}
"""

# Hosting headers (Netlify and Cloudflare Pages read _headers). No scripts, no third parties.
HEADERS = """/*
  Content-Security-Policy: default-src 'none'; img-src 'self'; style-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'
  X-Content-Type-Options: nosniff
  Referrer-Policy: no-referrer
  Permissions-Policy: camera=(), microphone=(), geolocation=(), interest-cohort=()
  Strict-Transport-Security: max-age=31536000
  X-Frame-Options: DENY
"""

NAV = [("index.html#how-it-works", "How it works"), ("index.html#privacy", "Privacy"),
       ("faq.html", "FAQ"), ("support.html", "Support")]

# Inline SVG icons (stroke-based, inherit currentColor; allowed by the CSP).
_ICON_PATHS = {
    "check": '<path d="M5 12.5l4.2 4.2L19 7"/>',
    "x": '<path d="M7 7l10 10M17 7L7 17"/>',
    "pause": '<rect x="6.5" y="5" width="3.5" height="14" rx="1.2"/><rect x="14" y="5" width="3.5" height="14" rx="1.2"/>',
    "shield": '<path d="M12 3l7 3v5.5c0 4.4-3 8-7 9.5-4-1.5-7-5.1-7-9.5V6l7-3z"/>',
    "book": '<path d="M4 5.5A2.5 2.5 0 016.5 3H20v15H6.5A2.5 2.5 0 004 20.5v-15z"/><path d="M4 20.5A2.5 2.5 0 016.5 18H20v3H6.5"/>',
    "globe": '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c2.5 2.6 3.8 5.6 3.8 9s-1.3 6.4-3.8 9c-2.5-2.6-3.8-5.6-3.8-9S9.5 5.6 12 3z"/>',
    "sun": '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>',
    "lock": '<rect x="5" y="10.5" width="14" height="10" rx="2.5"/><path d="M8 10.5V7.5a4 4 0 018 0v3"/>',
    "user": '<circle cx="12" cy="8" r="4"/><path d="M4 21c1.2-4 4.3-6 8-6s6.8 2 8 6"/>',
    "phone": '<rect x="6.5" y="2.5" width="11" height="19" rx="2.5"/><path d="M10.5 18.5h3"/>',
    "eye-off": '<path d="M3 3l18 18M10.6 5.1A10.4 10.4 0 0112 5c5 0 8.7 4 10 7-.5 1.2-1.4 2.6-2.6 3.9M6.2 6.3C4.2 7.7 2.8 9.8 2 12c1.3 3 5 7 10 7 1.6 0 3-.4 4.3-1"/><path d="M9.9 9.9a3 3 0 004.2 4.2"/>',
    "hand": '<path d="M7 11V5.5a1.5 1.5 0 013 0V11M10 10V4a1.5 1.5 0 013 0v6M13 10V5a1.5 1.5 0 013 0v7"/><path d="M16 9.5a1.5 1.5 0 013 0V14a7 7 0 01-7 7h-.6a6 6 0 01-4.6-2.2L4 14.5a1.6 1.6 0 012.4-2.1L7 13"/>',
    "a11y": '<circle cx="12" cy="4.5" r="1.8"/><path d="M5 8.5l7 1.5 7-1.5M12 10v5M9 21l3-6 3 6"/>',
}


def icon(name):
    return (f'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" '
            f'stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">{_ICON_PATHS[name]}</svg>')


def checks(items, positive=True):
    mark = icon("check" if positive else "x")
    rows = "".join(f"<li>{mark}<span>{text}</span></li>" for text in items)
    return f'<ul class="checks {"yes" if positive else "no"}">{rows}</ul>'


def public_path(config, path):
    """The path a visitor ends up on: "" for home, and no .html when the host strips it."""
    if path == "index.html":
        return ""
    return path[:-5] if config["clean_urls"] and path.endswith(".html") else path


def page(config, preview, path, title, description, body, index=True):
    domain = config["domain"] if configured(config, "domain") else ""
    canonical = f"{domain}/{public_path(config, path)}" if domain else ""
    image = f"{domain}/assets/icon-512.png" if domain else "assets/icon-512.png"
    full_title = f"{BRAND} — A pause before the scroll" if path == "index.html" else f"{title} · {BRAND}"
    meta = [
        f'<meta name="description" content="{html.escape(description)}">',
        '<meta property="og:type" content="website">',
        f'<meta property="og:site_name" content="{BRAND}">',
        f'<meta property="og:title" content="{html.escape(full_title)}">',
        f'<meta property="og:description" content="{html.escape(description)}">',
        f'<meta property="og:image" content="{image}">',
        f'<meta property="og:image:alt" content="The {BRAND} app icon">',
        '<meta name="twitter:card" content="summary">',
        f'<meta name="twitter:title" content="{html.escape(full_title)}">',
        f'<meta name="twitter:description" content="{html.escape(description)}">',
    ]
    if canonical:
        meta += [f'<link rel="canonical" href="{canonical}">', f'<meta property="og:url" content="{canonical}">']
    if preview or not index:
        meta.append('<meta name="robots" content="noindex">')
    current = ' aria-current="page"'
    nav = "".join(
        f'<li><a href="{href}"{current if href == path else ""}>{label}</a></li>'
        for href, label in NAV)
    year = datetime.date.today().year
    address = f'<p>{html.escape(config["contact_address"])}</p>' if configured(config, "contact_address") else ""
    banner = ('<div class="preview" role="note">Preview build — not for publication. '
              'Highlighted values still need to be configured.</div>') if preview else ""
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(full_title)}</title>
{chr(10).join(meta)}
<meta name="theme-color" content="#FFFFFF">
<link rel="icon" type="image/png" sizes="32x32" href="assets/favicon-32.png">
<link rel="apple-touch-icon" href="assets/apple-touch-icon.png">
<link rel="stylesheet" href="assets/site.css">
</head>
<body>
<a class="skip" href="#content">Skip to content</a>
{banner}
<header class="site"><div class="wrap">
<a class="brand" href="index.html"><img src="assets/icon-64.png" alt="" width="30" height="30">{BRAND}</a>
<nav class="main" aria-label="Main"><ul>{nav}</ul></nav>
</div></header>
<main id="content">
{body}
</main>
<footer class="site"><div class="wrap">
<div class="foot">
<div><a class="brand" href="index.html"><img src="assets/icon-64.png" alt="" width="30" height="30">{BRAND}</a><p>A pause before the scroll.<br>For iPhone.</p></div>
<nav aria-labelledby="f-product"><h2 id="f-product">Product</h2><ul>
<li><a href="index.html#how-it-works">How it works</a></li>
<li><a href="index.html#features">Features</a></li>
<li><a href="faq.html">FAQ</a></li></ul></nav>
<nav aria-labelledby="f-help"><h2 id="f-help">Help</h2><ul>
<li><a href="support.html">Support</a></li>
<li><a href="support.html#contact">Contact</a></li></ul></nav>
<nav aria-labelledby="f-legal"><h2 id="f-legal">Legal</h2><ul>
<li><a href="privacy.html">Privacy Policy</a></li>
<li><a href="terms.html">Terms of Use</a></li></ul></nav>
</div>
<div class="legal">
<p>© {year} {value(config, "legal_name")}</p>
{address}
<p>{BRAND} is not affiliated with or endorsed by any religious organisation. Apple, iPhone, App Store and Screen Time are trademarks of Apple Inc.</p>
</div>
</div></footer>
</body>
</html>
"""


def page_head(title, subtitle):
    return f'<div class="page-head"><div class="wrap narrow"><h1>{title}</h1><p>{subtitle}</p></div></div>'


# ---------------------------------------------------------------- pages

def launch_block(config):
    """A real download link once the app is live; until then, an honest pre-launch note."""
    if configured(config, "app_store_url"):
        url = html.escape(config["app_store_url"])
        return f'<a class="button" href="{url}">Download on the App Store</a>', ""
    return "", f'<p class="notice">{BRAND} is not yet available on the App Store.</p>'


def home(config, ios):
    download, notice = launch_block(config)
    primary = download or '<a class="button" href="#how-it-works">See how it works</a>'
    secondary = '<a class="button secondary" href="faq.html">Read the FAQ</a>'
    trust = "".join(f"<li>{icon('check')}{t}</li>" for t in
                    ("No account", "No ads or tracking", "Stays on your iPhone"))
    return f"""
<div class="wrap">
<section class="hero" aria-labelledby="hero-title">
<div>
<span class="kicker">For iPhone · iOS {ios} or later</span>
<h1 id="hero-title">A pause before the scroll.</h1>
<p class="lede">{BRAND} places a gentle pause in front of the apps you choose. Take a short moment of prayer, scripture, a mantra, a dua or quiet reflection — then continue with intention.</p>
<div class="actions">{primary}{secondary}</div>
{notice}
<ul class="trust">{trust}</ul>
</div>
<figure class="device">
<div class="phone"><div class="screen">
<img src="assets/icon-512.png" alt="" width="68" height="68">
<div class="s-title">You chose to protect this app</div>
<div class="s-sub">Take a moment to pray before opening it.</div>
<div class="s-primary">Begin</div>
<div class="s-secondary">Not now</div>
</div></div>
<figcaption>Illustration of {BRAND}'s pause screen, using the app's own wording.</figcaption>
</figure>
</section>
</div>

<div class="strip"><div class="wrap"><ul>
<li><span class="icon">{icon('pause')}</span><div><strong>Intentional pauses</strong><span>Before the apps you choose</span></div></li>
<li><span class="icon">{icon('book')}</span><div><strong>Your tradition</strong><span>Or faith-neutral moments</span></div></li>
<li><span class="icon">{icon('lock')}</span><div><strong>Private by design</strong><span>No account, no servers</span></div></li>
<li><span class="icon">{icon('hand')}</span><div><strong>You stay in control</strong><span>Turn it off at any time</span></div></li>
</ul></div></div>

<section class="band" id="how-it-works" aria-labelledby="how-title"><div class="wrap">
<div class="section-head"><h2 id="how-title">How it works</h2><p>Three steps, all on your iPhone, using Apple's Screen Time with your permission.</p></div>
<div class="steps">
<ol class="step-list">
<li><span class="num">1</span><div><h3>Choose apps and your practice</h3><p>Pick the apps, categories or websites to pause before — up to 50 of each, in Apple's private picker. Choose Christian, Muslim, Hindu or faith-neutral moments, with an optional tradition.</p></div></li>
<li><span class="num">2</span><div><h3>A pause appears</h3><p>When you open a protected app, {BRAND}'s pause screen appears first. Tap Begin, or Not now to close the app.</p></div></li>
<li><span class="num">3</span><div><h3>Take your moment, then continue</h3><p>After a short prayer, verse, mantra, dua or reflection, your apps open for 5, 15, 30 or 60 minutes, or the rest of the day. Then the pause returns.</p></div></li>
</ol>
<figure class="device">
<div class="phone"><div class="screen moment">
<div class="s-title">Sit quietly for a moment.</div>
<div class="s-sub">Breathe slowly. Let your shoulders fall. When you're ready, continue.</div>
<div class="s-primary">I'm ready</div>
</div></div>
<figcaption>Illustration of a faith-neutral moment, using the app's own wording.</figcaption>
</figure>
</div>
</div></section>

<section class="band soft" id="features" aria-labelledby="features-title"><div class="wrap">
<div class="section-head"><h2 id="features-title">Made for intention, not pressure</h2><p>Everything {BRAND} does today — nothing it doesn't.</p></div>
<div class="grid">
<div class="card"><span class="icon">{icon('pause')}</span><h3>Intentional app pauses</h3><p>Opening a protected app becomes a decision rather than a reflex.</p></div>
<div class="card"><span class="icon">{icon('shield')}</span><h3>Built on Screen Time</h3><p>Uses Apple's Screen Time frameworks with your permission. Turn protection off whenever you like.</p></div>
<div class="card"><span class="icon">{icon('book')}</span><h3>Prayer and reflection</h3><p>Short moments for your tradition. Religious texts appear only after review; composed prayers are clearly labelled.</p></div>
<div class="card"><span class="icon">{icon('globe')}</span><h3>Several traditions</h3><p>Christianity, Islam and Hinduism with optional traditions — or faith-neutral moments of breath and intention.</p></div>
<div class="card"><span class="icon">{icon('sun')}</span><h3>A quiet journey</h3><p>See your completed moments over time. No streak pressure, no badges designed to compel.</p></div>
<div class="card"><span class="icon">{icon('a11y')}</span><h3>Accessible</h3><p>Built with system text styles for Dynamic Type, VoiceOver labels and Reduce Motion support.</p></div>
</div>
<div class="chips" aria-label="Supported traditions">
<span>Christianity<small>Catholic · Orthodox · Protestant · Anglican · Non-denominational</small></span>
<span>Islam<small>Sunni · Shia</small></span>
<span>Hinduism<small>Shaiva · Vaishnava · Shakta · Smarta</small></span>
<span>Faith-neutral</span>
</div>
</div></section>

<section class="band" aria-labelledby="screen-time-title"><div class="wrap">
<div class="section-head"><h2 id="screen-time-title">Screen Time, explained honestly</h2><p>What {BRAND} can see and do — and what iOS doesn't allow.</p></div>
<div class="two">
<div class="panel"><h3>What access means</h3>{checks([
    f"{BRAND} asks for Screen Time access for your own iPhone; iOS confirms with Face ID, Touch ID or your passcode.",
    "It receives anonymous tokens for the apps you pick — never their names, and never how long you use them.",
    f"If you don't allow access, nothing is paused and the rest of {BRAND} still works.",
    "You can turn protection off in the app, or remove access in the Settings app, at any time.",
])}</div>
<div class="panel"><h3>What it can't do</h3>{checks([
    "Block phone calls, silence other apps' notifications or turn on Focus — iOS doesn't allow it.",
    "Schedule anything shorter than 15 minutes, so short unlocks end after at most 15 minutes.",
    "Supervise someone else's device. It isn't a parental-control service.",
], positive=False)}</div>
</div>
</div></section>

<section class="band soft" id="privacy" aria-labelledby="privacy-title"><div class="wrap">
<div class="two">
<div>
<h2 id="privacy-title">Your prayers stay yours.</h2>
<p class="lede">{BRAND} has no account and no servers for your data. What you choose and pray stays on your iPhone.</p>
<div class="actions"><a class="button secondary" href="privacy.html">Read the Privacy Policy</a></div>
</div>
<div class="panel">{checks([
    "No account and no sign-in",
    "Your practice, check-ins and history are stored only on your iPhone",
    "No analytics, advertising or tracking code, and no third-party libraries",
    "Delete everything at any time in Settings → Delete all my data",
])}</div>
</div>
</div></section>

<section class="band" aria-labelledby="why-title"><div class="wrap narrow center">
<p class="kicker">Why {BRAND}</p>
<h2 id="why-title" class="visually-hidden">Why {BRAND}</h2>
<blockquote class="why">We reach for our phones many times a day without deciding to. {BRAND} gives that reflex a different first step.</blockquote>
<p class="lede center">It doesn't take your phone away, and it doesn't promise to change your habits, your health or your faith. It simply makes room for a pause.</p>
</div></section>

<section class="band" aria-labelledby="cta-title"><div class="wrap"><div class="cta">
<h2 id="cta-title">Make room for a pause.</h2>
<p>Questions about Screen Time, privacy or setup? The answers are a click away.</p>
<div class="actions">{download or '<a class="button" href="faq.html">Read the FAQ</a>'}<a class="button secondary" href="support.html">Get support</a></div>
</div></div></section>
"""


FAQ = [
    ("What is Beloved?",
     "<p>An iPhone app that places a pause in front of the apps you choose. Before you continue, it offers a short moment of prayer, scripture, a mantra, a dua or a reflection for your practice.</p>"),
    ("How does the app pausing work?",
     "<p>With your permission, Beloved uses Apple's Screen Time frameworks. You choose apps, categories or websites (up to 50 of each). When you open one, iOS shows Beloved's pause screen. Tap Begin for your moment; afterwards the apps open for the time you chose — 5, 15, 30 or 60 minutes, or the rest of the day — and then the pause returns.</p>"
     "<p>iOS can't schedule anything shorter than 15 minutes, so with a 5-minute choice the apps close again after at most 15 minutes.</p>"),
    ("Can Beloved block calls or notifications?",
     "<p>No. iOS doesn't let apps block phone calls, silence other apps' notifications or turn on Focus.</p>"),
    ("Does Beloved read my messages?",
     "<p>No. Beloved has no access to your messages, e-mail, photos, contacts or the content of any app.</p>"),
    ("Does Beloved track my location?",
     "<p>No. Beloved never asks for location access and contains no tracking code.</p>"),
    ("What Screen Time permission does Beloved need?",
     "<p>Beloved asks for Screen Time access for your own iPhone. iOS asks you to confirm with Face ID, Touch ID or your passcode. Beloved receives anonymous tokens for the apps you pick — not their names, and not how long you use them.</p>"),
    ("What happens if I don't allow Screen Time access?",
     "<p>Nothing is paused, and the rest of Beloved still works — you can open a moment from Today at any time. You can allow access later in Beloved's Protection tab.</p>"),
    ("Why does Beloved ask for notifications?",
     "<p>Only for one thing: when you tap Begin on a pause screen, iOS may not be able to open Beloved directly, so a notification takes you to your moment. If you say no, pauses still work. You can change this later in Beloved → Settings → Notifications.</p>"),
    ("Can I choose which apps are protected?",
     "<p>Yes. You choose every app, category and website, and you can change or remove them in the Protection tab at any time.</p>"),
    ("Is my data sent to a server?",
     "<p>No. Beloved has no servers for your data and no account. Everything stays on your iPhone and in your own device backups.</p>"),
    ("How do I reset my setup?",
     "<p>Change your practice and preferences in Settings, and your protected apps in the Protection tab. To start completely fresh, use Settings → Delete all my data; Beloved then shows setup again.</p>"),
    ("How do I delete my data?",
     "<p>Open Beloved → Settings → Delete all my data. This removes your profile, check-ins and history, and removes all pauses. Deleting the app also removes its data. There is no account to delete.</p>"),
    ("Is Beloved affiliated with a particular religion?",
     "<p>No. Beloved is not affiliated with or endorsed by any religious organisation, and nothing in it is religious instruction.</p>"),
    ("Which traditions does Beloved support?",
     "<p>Christianity (Catholic, Orthodox, Protestant, Anglican or non-denominational), Islam (Sunni or Shia) and Hinduism (Shaiva, Vaishnava, Shakta or Smarta), plus faith-neutral moments. Choosing a tradition is optional.</p>"),
    ("Does Beloved cost anything or have subscriptions?",
     "<p>This version has no in-app purchases and no subscriptions.</p>"),
]


def faq():
    items = "\n".join(f"<details><summary>{html.escape(q)}</summary>{a}</details>" for q, a in FAQ)
    return (page_head("Frequently asked questions", f"How {BRAND} works, what it can and can't do, and how your privacy is protected.")
            + f"""<div class="doc-body"><div class="wrap narrow">
<div class="faq-list">{items}</div>
<p class="muted center notice">Didn't find your answer? <a href="support.html#contact">Contact support</a>.</p>
</div></div>""")


def support(config, ios):
    if configured(config, "support_email"):
        email = html.escape(config["support_email"])
        contact = f'<a href="mailto:{email}">{email}</a>'
        button = f'<div class="actions"><a class="button" href="mailto:{email}">E-mail support</a></div>'
    else:
        contact, button = value(config, "support_email"), ""
    return (page_head(f"{BRAND} support", "Help with pauses, Screen Time access, notifications and your data.")
            + f"""<div class="doc-body"><div class="wrap">
<div class="help-grid">
<div class="panel" id="requirements"><h2>Requirements</h2><ul>
<li>An iPhone running iOS {ios} or later.</li>
<li>Screen Time access, which you allow inside {BRAND}, for pauses to work.</li>
</ul></div>
<div class="panel"><h2>Pauses don't appear</h2><ul>
<li>Open {BRAND} → Protection and check that Screen Time access is allowed, at least one app is chosen and Protection is on.</li>
<li>If {BRAND} says “Confirm your apps”, tap Choose apps again — iOS sometimes asks you to reconfirm.</li>
<li>If you recently tapped Begin, the apps may still be open for the time you chose.</li>
</ul></div>
<div class="panel"><h2>Screen Time access</h2><ul>
<li>Declined it? Open {BRAND} → Protection and tap Allow Screen Time access.</li>
<li>Turned it off in the Settings app? {BRAND} shows “Protection is paused”. Allow access again — your chosen apps are kept.</li>
<li>iOS confirms access with Face ID, Touch ID or your passcode. {BRAND} never sees your passcode.</li>
</ul></div>
<div class="panel"><h2>Tapping Begin doesn't open {BRAND}</h2><ul>
<li>On some iOS versions, apps can't be opened directly from a pause screen, so {BRAND} sends a notification instead — tap it to begin.</li>
<li>No notification? Open {BRAND} → Settings → Notifications. If they're off, it takes you to the right place in the Settings app.</li>
</ul></div>
<div class="panel"><h2>Starting over</h2><ul>
<li>Settings → Delete all my data removes everything {BRAND} stored and shows setup again. There is no account.</li>
<li>More answers are in the <a href="faq.html">FAQ</a>.</li>
</ul></div>
</div>
<div class="contact-card wrap narrow" id="contact">
<h2>Contact and bug reports</h2>
<p>E-mail {contact}. To help us fix a problem quickly, please include:</p>
<ul class="prose">
<li>your iPhone model and iOS version (Settings → General → About);</li>
<li>the {BRAND} version (in {BRAND} → Settings → About);</li>
<li>what you did, what you expected, and what happened instead.</li>
</ul>
<p class="muted">Never send your passcode or Apple Account password — we will never ask for them. Please leave out prayer content or anything else you'd rather keep private.</p>
{button}
<p class="muted">See also the <a href="privacy.html">Privacy Policy</a> and <a href="terms.html">Terms of Use</a>.</p>
</div>
</div></div>""")


def split_title(markdown):
    """Use the document's own "# " heading as the page title (one <h1> per page)."""
    first, _, rest = markdown.lstrip().partition("\n")
    if not first.startswith("# "):
        sys.exit("Legal documents must start with a '# ' heading")
    return first[2:].strip(), rest


def legal(title, subtitle, markdown):
    return page_head(title, subtitle) + f'<div class="doc-body"><div class="wrap narrow prose">{markdown}</div></div>'


def not_found():
    return (page_head("Page not found", "That page doesn't exist or has moved.")
            + """<div class="doc-body"><div class="wrap narrow">
<div class="actions"><a class="button" href="index.html">Go to the home page</a><a class="button secondary" href="faq.html">Read the FAQ</a><a class="button secondary" href="support.html">Support</a></div>
</div></div>""")


# ---------------------------------------------------------------- assets

def write_assets(out_dir):
    assets = os.path.join(out_dir, "assets")
    os.makedirs(assets, exist_ok=True)
    with open(os.path.join(assets, "site.css"), "w", encoding="utf-8") as handle:
        handle.write(STYLE)
    for name, _ in ICON_SIZES:
        source = os.path.join(STATIC_ASSETS, name)
        if not os.path.exists(source):
            sys.exit(f"Missing {source}: run `python3 website/build.py --refresh-icons` on a Mac.")
        shutil.copyfile(source, os.path.join(assets, name))


def refresh_icons():
    """Regenerate the committed icons from the app icon (macOS: uses sips)."""
    if not shutil.which("sips"):
        sys.exit("--refresh-icons needs macOS (sips).")
    os.makedirs(STATIC_ASSETS, exist_ok=True)
    for name, size in ICON_SIZES:
        target = os.path.join(STATIC_ASSETS, name)
        shutil.copyfile(ICON, target)
        subprocess.run(["sips", "-Z", str(size), target], check=True, capture_output=True)
        print("wrote", target)


# ---------------------------------------------------------------- build

def build(config, preview, out_dir):
    ios = minimum_ios()
    with open(POLICY, encoding="utf-8") as handle:
        policy = handle.read()
    if configured(config, "support_email"):
        policy = policy.replace(
            "You can contact the developer through the support link on Beloved's App Store page.",
            f"You can contact the developer at {config['support_email']} or through the support link on Beloved's App Store page.",
        )
    with open(TERMS, encoding="utf-8") as handle:
        terms = handle.read()
    governing = f"## Governing law\n\n{config['governing_law']}" if configured(config, "governing_law") else ""
    terms = terms.replace("{{GOVERNING_LAW_SECTION}}", governing)
    policy_title, policy_body = split_title(policy)
    terms_title, terms = split_title(terms)
    terms_html = markdown_to_html(terms, {
        "LEGAL_NAME": value(config, "legal_name"),
        "EFFECTIVE_DATE": value(config, "terms_effective_date"),
        "SUPPORT_EMAIL": value(config, "support_email"),
    })

    def make(path, title, description, body, index=True):
        return page(config, preview, path, title, description, body, index)

    pages = {
        "index.html": make("index.html", BRAND, DESCRIPTION, home(config, ios)),
        "faq.html": make("faq.html", "FAQ", "Answers about how Beloved pauses apps, Screen Time access, privacy and supported traditions.", faq()),
        "support.html": make("support.html", "Support", "Get help with Beloved: requirements, pauses, Screen Time access, notifications and contact.", support(config, ios)),
        "privacy.html": make("privacy.html", "Privacy Policy", "What Beloved stores, where it stays, and how to delete it.", legal(html.escape(policy_title), "What Beloved stores, where it stays, and how to delete it.", markdown_to_html(policy_body))),
        "terms.html": make("terms.html", "Terms of Use", "The terms for using the Beloved app and website.", legal(html.escape(terms_title), "The terms for using the Beloved app and this website.", terms_html)),
        "404.html": make("404.html", "Page not found", DESCRIPTION, not_found(), index=False),
    }
    if os.path.isdir(out_dir):
        shutil.rmtree(out_dir)  # generated output only; never a source directory
    os.makedirs(out_dir)
    for name, content in pages.items():
        with open(os.path.join(out_dir, name), "w", encoding="utf-8") as handle:
            handle.write(content)
    write_assets(out_dir)
    with open(os.path.join(out_dir, "_headers"), "w", encoding="utf-8") as handle:
        handle.write(HEADERS)

    domain = config["domain"] if configured(config, "domain") else ""
    if preview or not domain:
        robots = "User-agent: *\nDisallow: /\n"
    else:
        robots = f"User-agent: *\nAllow: /\n\nSitemap: {domain}/sitemap.xml\n"
        urls = "".join(
            f"  <url><loc>{domain}/{public_path(config, p)}</loc></url>\n"
            for p in pages if p != "404.html")
        with open(os.path.join(out_dir, "sitemap.xml"), "w", encoding="utf-8") as handle:
            handle.write('<?xml version="1.0" encoding="UTF-8"?>\n'
                         '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n' + urls + "</urlset>\n")
    with open(os.path.join(out_dir, "robots.txt"), "w", encoding="utf-8") as handle:
        handle.write(robots)
    return sorted(os.listdir(out_dir))


def safe_output_dir(path):
    """Refuse to wipe anything that isn't a generated-output folder."""
    real = os.path.realpath(path)
    protected = {os.path.realpath(p) for p in (ROOT, WEBSITE, os.path.join(WEBSITE, "content"), os.path.expanduser("~"), "/")}
    if real in protected or (os.path.isdir(real) and os.listdir(real) and not os.path.exists(os.path.join(real, "index.html"))):
        sys.exit(f"Refusing to use {path} as the output folder (it isn't a previous build).")
    return real


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--config", help="JSON file with the owner values (see site.example.json)")
    source.add_argument("--config-env", action="store_true", help="read BELOVED_* environment variables instead")
    source.add_argument("--refresh-icons", action="store_true", help="regenerate website/static/assets from the app icon")
    parser.add_argument("--preview", action="store_true", help="allow missing/example values; marks gaps and sets noindex")
    parser.add_argument("--out", default=os.path.join(WEBSITE, "public"))
    args = parser.parse_args()
    if args.refresh_icons:
        refresh_icons()
        return
    config = load_config(None if args.config_env else args.config, args.preview)
    out_dir = safe_output_dir(args.out)
    build(config, args.preview, out_dir)
    check = [sys.executable, os.path.join(WEBSITE, "check.py"), out_dir] + ([] if args.preview else ["--production"])
    if subprocess.run(check).returncode != 0:
        sys.exit("Site check failed — see above.")
    print(f"Built {'PREVIEW (not for publication)' if args.preview else 'production site'} in {out_dir}")


if __name__ == "__main__":
    main()
