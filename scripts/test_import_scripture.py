"""Tests for scripts/import_scripture.py.  Run: python3 -m unittest scripts/test_import_scripture.py"""
import importlib.util
import json
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
_spec = importlib.util.spec_from_file_location("import_scripture", HERE / "import_scripture.py")
imp = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(imp)

RESOURCES = imp.OUT


class TransliterationTests(unittest.TestCase):
    def test_inherent_vowel_virama_and_signs(self):
        self.assertEqual(imp.devanagari_to_iast("धर्मक्षेत्रे कुरुक्षेत्रे"), "dharmakṣetre kurukṣetre")
        self.assertEqual(imp.devanagari_to_iast("कर्मण्येवाधिकारस्ते"), "karmaṇyevādhikāraste")

    def test_anusvara_visarga_avagraha_and_dandas(self):
        self.assertEqual(imp.devanagari_to_iast("सङ्गोऽस्त्वकर्मणि ॥"), "saṅgo'stvakarmaṇi ||")
        self.assertEqual(imp.devanagari_to_iast("युयुत्सवः।"), "yuyutsavaḥ |")
        self.assertEqual(imp.devanagari_to_iast("शरीरं"), "śarīraṃ")

    def test_independent_vowels_and_om(self):
        self.assertEqual(imp.devanagari_to_iast("ॐ ऋषि ऐ औ"), "oṃ ṛṣi ai au")

    def test_unmapped_characters_fail_loudly(self):
        with self.assertRaises(ValueError):
            imp.devanagari_to_iast("ि")  # orphan vowel sign
        with self.assertRaises(ValueError):
            imp.devanagari_to_iast("क॑")  # Vedic accent, not mapped


class GitaNormalisationTests(unittest.TestCase):
    def test_speaker_and_number_are_split_off(self):
        speaker, text = imp.normalise_gita_verse(
            "धृतराष्ट्र उवाच\n\nधर्मक्षेत्रे कुरुक्षेत्रे समवेता युयुत्सवः।\n\nमामकाः पाण्डवाश्चैव किमकुर्वत सञ्जय।।1.1।।\n ")
        self.assertEqual(speaker, "धृतराष्ट्र उवाच")
        self.assertEqual(text, "धर्मक्षेत्रे कुरुक्षेत्रे समवेता युयुत्सवः।\nमामकाः पाण्डवाश्चैव किमकुर्वत सञ्जय ॥")

    def test_sandhi_speaker_without_space_and_missing_breaks(self):
        speaker, text = imp.normalise_gita_verse(
            "श्री भगवानुवाचइदं शरीरं कौन्तेय क्षेत्रमित्यभिधीयते।एतद्यो वेत्ति तं प्राहुः क्षेत्रज्ञ इति तद्विदः।।13.2।।")
        self.assertEqual(speaker, "श्री भगवानुवाच")
        self.assertTrue(text.startswith("इदं शरीरं"))
        self.assertIn("।\nएतद्यो", text)

    def test_verse_text_containing_uvaca_is_not_a_speaker(self):
        speaker, text = imp.normalise_gita_verse("तमुवाच हृषीकेशः प्रहसन्निव भारत।\nसेनयोरुभयोर्मध्ये विषीदन्तमिदं वचः।।2.10।।")
        self.assertIsNone(speaker)
        self.assertTrue(text.startswith("तमुवाच"))

    def test_legacy_vowel_order_is_fixed(self):
        _, text = imp.normalise_gita_verse("यच्छ्रेयः स्यान्निश्िचतं ब्रूहि तन्मे।।2.7।।")
        self.assertIn("निश्चितं", text)

    def test_malformed_closing_number_is_tolerated_but_required(self):
        _, text = imp.normalise_gita_verse("तत्र श्रीर्विजयो भूतिर्ध्रुवा नीतिर्मतिर्मम।।18.78।\n ")
        self.assertTrue(text.endswith("मम ॥"))
        with self.assertRaises(ValueError):
            imp.normalise_gita_verse("no verse number")


class ArnoldTests(unittest.TestCase):
    SAMPLE = "\n".join([
        "*** START OF THE PROJECT GUTENBERG EBOOK X ***", "Preface text", "CHAPTER I", "", "",
        "  Krishna.", "  How hath this weakness taken thee?--Nay![FN#1]", "", "  Arjuna.", "",
        "  Line one", "  Line two", "", "  HERE ENDETH CHAPTER I. OF THE BHAGAVAD-GITA,",
        '  Entitled "Arjun-Vishad,"', '  Or "The Book of the Distress', '  of Arjuna."', "", "[FN#1] note",
        "*** END OF THE PROJECT GUTENBERG EBOOK X ***",
    ])

    def test_paragraphs_speakers_and_wrapped_titles(self):
        chapters, speakers, titles = imp.parse_arnold(self.SAMPLE)
        self.assertEqual(chapters, [["How hath this weakness taken thee?—Nay!", "Line one\nLine two"]])
        self.assertEqual(speakers, {"1:1": "Krishna", "1:2": "Arjuna"})
        self.assertEqual(titles, ["The Book of the Distress of Arjuna"])


class ReferenceTests(unittest.TestCase):
    def test_parse_ref(self):
        self.assertEqual(imp.parse_ref("PSA 46:10"), ("PSA", 46, 10, 10))
        self.assertEqual(imp.parse_ref("QUR 94:5-6"), ("QUR", 94, 5, 6))
        with self.assertRaises(ValueError):
            imp.parse_ref("QUR 94:6-5")

    def test_vpl_gaps_become_empty_slots(self):
        books = imp.parse_vpl("MAR 1:1 a\nMAR 1:3 b\n", ["MAR"])
        self.assertEqual(books[0]["chapters"], [["a", "", "b"]])
        with self.assertRaises(ValueError):
            imp.parse_vpl("MAR 2:1 a\n", ["MAR"])  # chapter 1 missing entirely


@unittest.skipUnless((RESOURCES / "scripture-library.json").exists(), "resources not built")
class BundledResourceTests(unittest.TestCase):
    def test_every_edition_file_matches_its_manifest(self):
        library = json.loads((RESOURCES / "scripture-library.json").read_text())
        for info in library["editions"]:
            text = json.loads((RESOURCES / f"{info['id']}.json").read_text())
            self.assertEqual([b["id"] for b in text["books"]], info["books"])
            self.assertEqual({b["id"]: len(b["chapters"]) for b in text["books"]}, info["chapterCounts"])
            self.assertTrue(info["attribution"])
            self.assertEqual(info["review"]["status"], "draft", "approval is a reviewer's decision, never the importer's")

    def test_tanzil_notice_is_carried_verbatim(self):
        library = json.loads((RESOURCES / "scripture-library.json").read_text())
        quran = next(e for e in library["editions"] if e["id"] == "quran.ar")
        self.assertIn(imp.TANZIL_NOTICE_MARK, quran["notice"])
        self.assertIn("CHANGING IT IS NOT ALLOWED", quran["notice"])


if __name__ == "__main__":
    unittest.main()
