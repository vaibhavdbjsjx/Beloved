#!/usr/bin/env python3
"""Tests for the website generator and checker.

    python3 -m unittest website/test_site.py -v

Builds into temporary folders only. The "production" values below use the reserved
.test TLD purely to exercise the code path; they are never written to the repository.
"""
import json
import os
import threading
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
BUILD = os.path.join(HERE, "build.py")
EXAMPLE = os.path.join(HERE, "site.example.json")
REAL_LOOKING = {
    "domain": "https://beloved-site.test",
    "support_email": "support.beloved@gmail.com",
    "legal_name": "Vaibhav S G",
    "terms_effective_date": "1 January 2027",
}


class SiteTestCase(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.out = os.path.join(self.tmp.name, "public")

    def tearDown(self):
        self.tmp.cleanup()

    def config(self, **values):
        path = os.path.join(self.tmp.name, "site.json")
        with open(path, "w", encoding="utf-8") as handle:
            json.dump(values, handle)
        return path

    def build(self, config, preview=False):
        args = [sys.executable, BUILD, "--config", config, "--out", self.out] + (["--preview"] if preview else [])
        return subprocess.run(args, capture_output=True, text=True)

    def read(self, name):
        with open(os.path.join(self.out, name), encoding="utf-8") as handle:
            return handle.read()



class SiteTests(SiteTestCase):
    # Production refusals

    def test_production_refuses_missing_values(self):
        result = self.build(self.config())
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("support e-mail address", result.stderr)
        self.assertFalse(os.path.exists(self.out))

    def test_production_refuses_the_example_template(self):
        result = self.build(EXAMPLE)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("example/placeholder value", result.stderr)

    def test_invalid_values_are_rejected_even_in_preview(self):
        for bad in ({"domain": "http://insecure.test"}, {"support_email": "not-an-address"},
                    {"app_store_url": "https://apps.apple.com/app/fake"}):
            result = self.build(self.config(**bad), preview=True)
            self.assertNotEqual(result.returncode, 0, bad)

    # Preview

    def test_preview_marks_gaps_and_is_not_indexable(self):
        result = self.build(EXAMPLE, preview=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        support = self.read("support.html")
        self.assertIn("support.beloved@gmail.com", support)
        self.assertNotIn("support@beloved.example", support, "example e-mail must never be shown as real")
        self.assertIn("mailto:support.beloved@gmail.com", support)
        self.assertIn('class="gap"', self.read("terms.html"))
        self.assertIn('content="noindex"', self.read("index.html"))
        self.assertIn("Disallow: /", self.read("robots.txt"))
        self.assertFalse(os.path.exists(os.path.join(self.out, "sitemap.xml")))

    # Production output

    def test_production_build_passes_the_checker(self):
        result = self.build(self.config(**REAL_LOOKING))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("site check passed (production)", result.stdout)
        index = self.read("index.html")
        self.assertIn('<link rel="canonical" href="https://beloved-site.test/">', index)
        self.assertIn('href="mailto:support.beloved@gmail.com"', self.read("support.html"))
        self.assertIn("Sitemap: https://beloved-site.test/sitemap.xml", self.read("robots.txt"))
        self.assertIn("Content-Security-Policy", self.read("_headers"))

    def test_no_download_button_without_a_real_app_store_link(self):
        self.build(self.config(**REAL_LOOKING))
        index = self.read("index.html")
        self.assertNotIn("Download on the App Store", index)
        self.assertIn("not yet available on the App Store", index)

    def test_download_button_with_a_real_app_store_link(self):
        url = "https://apps.apple.com/us/app/beloved/id1234567890"
        self.build(self.config(**REAL_LOOKING, app_store_url=url))
        index = self.read("index.html")
        self.assertIn(f'href="{url}"', index)
        self.assertNotIn("not yet available", index)

    def test_governing_law_only_when_supplied(self):
        self.build(self.config(**REAL_LOOKING))
        self.assertNotIn("Governing law", self.read("terms.html"))
        self.build(self.config(**REAL_LOOKING, governing_law="Supplied by counsel."))
        self.assertIn("Governing law", self.read("terms.html"))
        self.assertNotIn("{{", self.read("terms.html"))

    def test_requirements_match_the_xcode_deployment_target(self):
        self.build(self.config(**REAL_LOOKING))
        with open(os.path.join(HERE, "..", "Config", "Shared.xcconfig"), encoding="utf-8") as handle:
            target = [l.split("=")[1].strip() for l in handle if l.startswith("IPHONEOS_DEPLOYMENT_TARGET")][0]
        self.assertIn(f"iOS {target.removesuffix('.0')} or later", self.read("support.html"))

    def test_privacy_page_is_the_bundled_policy(self):
        self.build(self.config(**REAL_LOOKING))
        policy_path = os.path.join(HERE, "..", "App", "PrayerLock", "Resources", "Legal", "PrivacyPolicy.md")
        with open(policy_path, encoding="utf-8") as handle:
            heading = handle.readline().lstrip("# ").strip()
        privacy = self.read("privacy.html")
        self.assertIn(f"<h1>{heading}</h1>", privacy)
        self.assertEqual(privacy.count("<h1"), 1)

    def test_refuses_to_wipe_a_non_build_folder(self):
        os.makedirs(self.out)
        with open(os.path.join(self.out, "keep.txt"), "w") as handle:
            handle.write("not a build")
        result = self.build(self.config(**REAL_LOOKING))
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(os.path.exists(os.path.join(self.out, "keep.txt")))


class HostingTests(SiteTestCase):
    def test_environment_variables_configure_a_hosted_build(self):
        env = {**os.environ, **{f"BELOVED_{k.upper()}": v for k, v in REAL_LOOKING.items()}}
        result = subprocess.run([sys.executable, BUILD, "--config-env", "--out", self.out],
                                capture_output=True, text=True, env=env)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('href="mailto:support.beloved@gmail.com"', self.read("support.html"))

    def test_hosted_build_fails_without_environment_values(self):
        env = {k: v for k, v in os.environ.items() if not k.startswith("BELOVED_")}
        result = subprocess.run([sys.executable, BUILD, "--config-env", "--out", self.out],
                                capture_output=True, text=True, env=env)
        self.assertNotEqual(result.returncode, 0)

    def test_clean_urls_change_canonicals_and_sitemap(self):
        result = self.build(self.config(**REAL_LOOKING, clean_urls=True))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('<link rel="canonical" href="https://beloved-site.test/privacy">', self.read("privacy.html"))
        self.assertIn("<loc>https://beloved-site.test/faq</loc>", self.read("sitemap.xml"))

    def test_icons_are_committed_and_sized(self):
        for name in ("icon-512.png", "apple-touch-icon.png", "icon-64.png", "favicon-32.png"):
            path = os.path.join(HERE, "static", "assets", name)
            with open(path, "rb") as handle:
                header = handle.read(24)
            self.assertEqual(header[:8], b"\x89PNG\r\n\x1a\n", name)
            width = int.from_bytes(header[16:20], "big")
            self.assertEqual(width, int(name.split("-")[-1].split(".")[0]) if name != "apple-touch-icon.png" else 180)

    def test_live_verifier_reports_a_host_without_security_headers(self):
        import importlib.util
        self.build(self.config(**REAL_LOOKING))
        spec = importlib.util.spec_from_file_location("verify_live", os.path.join(HERE, "verify_live.py"))
        verify_live = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(verify_live)

        class Quiet(SimpleHTTPRequestHandler):
            def log_message(self, *args):
                pass

        server = ThreadingHTTPServer(("127.0.0.1", 0), partial(Quiet, directory=self.out))
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            problems = verify_live.verify(f"http://127.0.0.1:{server.server_port}", check_http_redirect=False)
        finally:
            server.shutdown()
            server.server_close()
        # Python's test server ignores _headers, so exactly the header checks must fail.
        self.assertTrue(problems)
        self.assertTrue(all("header" in p for p in problems), problems)

    def test_live_verifier_rejects_a_site_that_is_not_beloved(self):
        import importlib.util
        os.makedirs(self.out)
        for name in ("index.html", "faq.html", "support.html", "privacy.html", "terms.html"):
            with open(os.path.join(self.out, name), "w") as handle:
                handle.write("<html><body>Domain parked</body></html>")
        spec = importlib.util.spec_from_file_location("verify_live", os.path.join(HERE, "verify_live.py"))
        verify_live = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(verify_live)

        class Quiet(SimpleHTTPRequestHandler):
            def log_message(self, *args):
                pass

        server = ThreadingHTTPServer(("127.0.0.1", 0), partial(Quiet, directory=self.out))
        threading.Thread(target=server.serve_forever, daemon=True).start()
        try:
            problems = verify_live.verify(f"http://127.0.0.1:{server.server_port}", check_http_redirect=False)
        finally:
            server.shutdown()
            server.server_close()
        self.assertTrue(any("not a Beloved page" in p for p in problems), problems)


class LiveVerifierTests(unittest.TestCase):
    def test_unreachable_site_is_a_failure_not_a_crash(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location("verify_live", os.path.join(HERE, "verify_live.py"))
        verify_live = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(verify_live)
        problems = verify_live.verify("https://beloved-unreachable.invalid")
        self.assertEqual(len(problems), 1)
        self.assertIn("unreachable", problems[0])
        result = subprocess.run([sys.executable, os.path.join(HERE, "verify_live.py"), "https://beloved-unreachable.invalid"],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertNotIn("Traceback", result.stderr)

    def test_plain_http_base_is_refused(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location("verify_live", os.path.join(HERE, "verify_live.py"))
        verify_live = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(verify_live)
        self.assertEqual(verify_live.verify("http://example.invalid"), ["base URL must start with https://"])


if __name__ == "__main__":
    unittest.main()
