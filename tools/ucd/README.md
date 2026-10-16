# tools/ucd: the Unicode Character Database

The data files of the Unicode Character Database, version 18.0.0, from
https://www.unicode.org/Public/UCD/latest/ucd/ (#156), fetched on
2026-10-17. tools/gen_unicode.py makes runtime/unicode_tables.c and
runtime/unicode_names.c from them, which `make` runs, and
tests/run/unicode_normalization.k and unicode_graphemes.k read
NormalizationTest.txt and GraphemeBreakTest.txt as their references.

The files are Unicode, Inc.'s, under the Unicode License v3 in
LICENSE.txt here, https://www.unicode.org/license.txt. To move to a newer
Unicode, replace the files and run `make`.
