#!/usr/bin/env python3
"""Tests for the release gate (validate-release.sh) and the content report.

    python3 -m unittest Config/test_release_tools.py -v
"""
import copy
import importlib.util
import os
import re
import subprocess
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

spec = importlib.util.spec_from_file_location("report", os.path.join(HERE, "release-content-report.py"))
report = importlib.util.module_from_spec(spec)
spec.loader.exec_module(report)


class ContentReportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        faiths = report.load(report.FAITHS)
        cls.cleared = report.cleared_editions(faiths)
        cls.editions = report.editions_by_id(faiths)
        cls.items = {item["id"]: item for item in report.load_items()}

    def approved(self, item_id):
        item = copy.deepcopy(self.items[item_id])
        item["review"]["status"] = "approved"
        return item

    def assertVisible(self, item, expected):
        self.assertEqual(report.is_release_visible(item, self.cleared), expected)
        self.assertEqual(not report.blocking_reasons(item, self.cleared, self.editions), expected)

    def test_draft_is_blocked(self):
        self.assertVisible(self.items["christianity.psalm-46-10"], False)

    def test_approved_public_domain_scripture_is_visible(self):
        self.assertVisible(self.approved("christianity.psalm-46-10"), True)

    def test_approved_scripture_from_a_pending_edition_is_blocked(self):
        # rigveda.sa is still pendingClearance in faiths.json.
        item = self.approved("islam.quran-94-5-6")
        item["segments"][0]["citation"]["edition"] = "rigveda.sa"
        self.assertVisible(item, False)
        self.assertTrue(any("rights pending" in r for r in report.blocking_reasons(item, self.cleared, self.editions)))

    def test_approved_item_still_labelled_draft_is_blocked(self):
        self.assertVisible(self.approved("christianity.prayer.attention"), False)

    def test_approved_item_with_a_real_author_label_is_visible(self):
        item = self.approved("christianity.prayer.attention")
        for segment in item["segments"]:
            if segment.get("author"):
                segment["author"] = "Named editor"
        self.assertVisible(item, True)

    def test_scripture_without_an_edition_is_blocked(self):
        item = self.approved("christianity.psalm-46-10")
        item["segments"][0]["citation"].pop("edition")
        self.assertVisible(item, False)

    def test_current_catalog_has_no_release_content(self):
        # Guards against content being promoted without review: update this test only
        # together with a real, recorded approval.
        visible = [i for i in self.items.values() if report.is_release_visible(i, self.cleared)]
        self.assertEqual(visible, [])


class RegisterTests(unittest.TestCase):
    def test_register_lists_every_item_with_its_release_state(self):
        result = subprocess.run(["python3", os.path.join(HERE, "release-content-report.py"), "--markdown"],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        rows = [line for line in result.stdout.splitlines() if re.match(r"^\| \d+ \| `", line)]
        self.assertEqual(len(rows), len(report.load_items()))
        self.assertTrue(all("**BLOCKED**" in row for row in rows), "no item is approved yet")

    def test_register_lists_every_scripture_edition_as_blocked_until_reviewed(self):
        result = subprocess.run(["python3", os.path.join(HERE, "release-content-report.py"), "--markdown"],
                                capture_output=True, text=True)
        library = report.load(report.SCRIPTURE)
        section = result.stdout.split("## Scripture reader", 1)[1].split("## How an item", 1)[0]
        for edition in library["editions"]:
            row = next(line for line in section.splitlines() if line.startswith(f"| `{edition['id']}`"))
            self.assertIn("**BLOCKED**", row)


class PrivacyBoundaryTests(unittest.TestCase):
    """Personal data stays in the app (DECISIONS D41): the Screen Time extensions, the
    protection module (whose state lives in the shared App Group) and the shield/notification
    copy must never touch the user's intentions, moods or name."""

    # The user's own data (not, e.g., AppBrand.displayName or an app's localizedDisplayName).
    PERSONAL = re.compile(r"\bintentions\b|profile\.displayName|\btodayMood\b|\bcheckIn\b|\bmood\b")

    def swift_sources(self, *roots):
        for root in roots:
            for folder, _, files in os.walk(os.path.join(ROOT, root)):
                for name in files:
                    if name.endswith(".swift"):
                        yield os.path.join(folder, name)

    def test_extensions_and_shared_state_never_reference_personal_fields(self):
        offenders = []
        for path in self.swift_sources("Extensions", "Packages/PrayerLockKit/Sources/PLProtection"):
            text = open(path, encoding="utf-8").read()
            offenders += [f"{os.path.relpath(path, ROOT)}: {m.group(0)}" for m in self.PERSONAL.finditer(text)]
        self.assertEqual(offenders, [])

    def test_shield_and_notification_copy_uses_no_personal_fields(self):
        text = open(os.path.join(ROOT, "App/PrayerLock/Sources/Support/DisplayStrings.swift"), encoding="utf-8").read()
        factory = text[text.index("enum ShieldCopyFactory"):]
        self.assertIsNone(self.PERSONAL.search(factory), "ShieldCopyFactory must not use personal data")


class ReleaseGateTests(unittest.TestCase):
    def run_gate(self, **settings):
        env = {"PATH": os.environ["PATH"], "SRCROOT": ROOT, **settings}
        result = subprocess.run(["sh", os.path.join(HERE, "validate-release.sh")], env=env,
                                capture_output=True, text=True)
        return result.returncode, result.stdout

    def test_archive_with_placeholder_identity_fails(self):
        code, out = self.run_gate(ACTION="install", CONFIGURATION="Release", PL_ENVIRONMENT="production",
                                  PL_BUNDLE_ID_PREFIX="unconfigured.beloved")
        self.assertEqual(code, 1)
        self.assertIn("error: Beloved identity is not configured", out)

    def test_archive_without_release_content_fails_even_with_identity(self):
        code, out = self.run_gate(ACTION="install", CONFIGURATION="Release", PL_ENVIRONMENT="production",
                                  PL_BUNDLE_ID_PREFIX="org.owner.app", DEVELOPMENT_TEAM="TEAM000000")
        self.assertEqual(code, 1)
        self.assertNotIn("identity is not configured", out)
        self.assertIn("error: Release content is incomplete", out)

    def test_release_configuration_problems_are_reported(self):
        code, out = self.run_gate(ACTION="install", CONFIGURATION="Release", PL_ENVIRONMENT="development",
                                  PL_ASSISTANT_ENDPOINT="https://api.invalid", PL_SUPPORT_URL="http://site.invalid",
                                  PL_PRIVACY_POLICY_URL="https://your-domain/privacy.html")
        self.assertEqual(code, 1)
        for text in ("PL_ENVIRONMENT = production", "PL_ASSISTANT_ENDPOINT is set",
                     "PL_SUPPORT_URL must be an https:// URL", "PL_PRIVACY_POLICY_URL is a placeholder"):
            self.assertIn(text, out)

    def test_release_build_warns_but_does_not_fail(self):
        code, out = self.run_gate(ACTION="build", CONFIGURATION="Release", CODE_SIGNING_ALLOWED="NO",
                                  PL_ENVIRONMENT="production")
        self.assertEqual(code, 0)
        self.assertIn("warning:", out)

    def test_unsigned_debug_build_is_silent(self):
        code, out = self.run_gate(ACTION="build", CONFIGURATION="Debug", CODE_SIGNING_ALLOWED="NO",
                                  PL_ENVIRONMENT="development")
        self.assertEqual((code, out), (0, ""))


if __name__ == "__main__":
    unittest.main()
