"""Tests for scripts/import_devotions.py.  Run: python3 -m unittest scripts/test_import_devotions.py"""
import importlib.util
import json
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
_spec = importlib.util.spec_from_file_location("import_devotions", HERE / "import_devotions.py")
dev = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(dev)


class MarkupTests(unittest.TestCase):
    def test_markup_is_removed_words_are_kept(self):
        raw = "{{font-size-x|10.0pt|''For use after the Collects''}} O God, who ''hast filled'' the world{{em}}with beauty &amp; light"
        self.assertEqual(dev.tidy(dev.strip_markup(raw)), "For use after the Collects O God, who hast filled the world with beauty & light")

    def test_hyphenated_words_across_pages_are_rejoined(self):
        self.assertEqual(dev.tidy(dev.strip_markup("our {{hws|wor|world}} {{hwe|ld|world}} today")), "our world today")

    def test_bcp_prayers_drop_headings_and_rubrics(self):
        page = ("'''Prayers for the World'''\n\n''1.  For Joy''\n\nO heavenly Father: open our eyes. ''Amen.''\n\n"
                "''2.  For Peace''\n\n''See also page 99.''\n\nEternal God, give peace. ''Amen.''\n\n")
        prayers, thanks = dev.parse_bcp([page])
        self.assertEqual(prayers[1], ("For Joy", "O heavenly Father: open our eyes. Amen."))
        self.assertEqual(prayers[2], ("For Peace", "Eternal God, give peace. Amen."))
        self.assertEqual(thanks, {})


class SanskritTests(unittest.TestCase):
    PAGE = "<poem>प्रथमं पदम् ।\nद्वितीयं पदम् ॥९॥</poem>\n[[File:x.jpg]]\n<poem>तत्सवितुर्वरेण्यं ।\nधियो यो नः ॥१०॥</poem>"

    def test_verses_span_poem_blocks(self):
        self.assertEqual(dev.rigveda_verse(self.PAGE, 10), "तत्सवितुर्वरेण्यं ।\nधियो यो नः ॥")
        with self.assertRaises(ValueError):
            dev.rigveda_verse(self.PAGE, 11)


class QuranTests(unittest.TestCase):
    def test_phrase_starts_at_a_whole_word_ignoring_marks(self):
        verse = "فَظَنَّ أَن لَّن نَّقْدِرَ عَلَيْهِ فَنَادَىٰ فِى ٱلظُّلُمَٰتِ أَن لَّآ إِلَٰهَ إِلَّآ أَنتَ"
        self.assertEqual(dev.phrase_from(verse, "لَّآ"), "لَّآ إِلَٰهَ إِلَّآ أَنتَ")
        with self.assertRaises(ValueError):
            dev.phrase_from(verse, "رَبِّ")

    def test_madda_forms_compare_equal(self):
        self.assertEqual(dev.bare("آ"), dev.bare("آ"))


OUT = dev.OUT


@unittest.skipUnless(OUT.exists(), "devotions.json not built")
class BuiltLibraryTests(unittest.TestCase):
    def test_everything_is_draft_and_cited(self):
        items = json.loads(OUT.read_text())
        self.assertGreaterEqual(len(items), 40)
        for item in items:
            self.assertEqual(item["review"]["status"], "draft", item["id"])
            sources = [s for s in item["segments"] if s["role"] == "sourceText"]
            self.assertTrue(sources, item["id"])
            for s in sources:
                self.assertTrue(s["citation"]["edition"] and s["citation"]["reference"], item["id"])


if __name__ == "__main__":
    unittest.main()
