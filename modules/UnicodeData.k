// modules/UnicodeData.k - the Unicode Character Database for Strings and
// codepoints (#156), after Python's unicodedata: what the prelude's String,
// which walks codepoints, leaves out. Written in Kelvin over
// runtime/unicode_data.c on the tables tools/gen_unicode.py makes from
// tools/ucd/, and built by kelvinc --prelude into UnicodeData.kh, which
// #import <UnicodeData> brings in, and an object that libkelvin holds (#504).
//
//     #import <UnicodeData>
//     var s = $"e\u0301 ﬁ 👨‍👩‍👧"
//     var c = s.normalize(nfc)                   // é, one codepoint; nfd, nfkc, nfkd too
//     var gs = s.graphemes                       // é, a space, ﬁ, a space, the family: five
//     for g in gs { println(g) }
//     var name = uchr("é").name
//     println(gs.count, " ", name, " ", uchr("é").category)
#import <kUnicodeData.h> as C

// the normalization forms: C's enum, whose enumerators are words
enum NormalForm { nfc, nfd, nfkc, nfkd }

// the library's functions, by their C names: a String borrowed in, a String out
let kv_ucd_normalize(s:const String^, form:i32):String
let kv_ucd_graphemes(s:const String^, out:String^^, count:size_t^):()
let kv_ucd_free_strings(at:String^, n:size_t):()
let kv_ucd_grapheme_len(p:const u8^, n:size_t):size_t
let kv_ucd_upper(s:const String^):String
let kv_ucd_lower(s:const String^):String
let kv_ucd_fold(s:const String^):String
let kv_ucd_to_upper(cp:u32):u32
let kv_ucd_to_lower(cp:u32):u32
let kv_ucd_to_fold(cp:u32):u32
let kv_ucd_category(cp:u32):cstr
let kv_ucd_name_of(cp:u32):String
let kv_ucd_combining(cp:u32):i32
let kv_ucd_decomposition(cp:u32, compat:bool):String
let kv_ucd_category_index(cp:u32):u8
let kv_ucd_script(cp:u32):i32
let kv_ucd_script_name(id:i32):cstr
let kv_ucd_property_id(name:cstr):i32
let kv_ucd_has_property(cp:u32, id:i32):bool

extend String {
    // the String normalized: s.normalize(nfc), nfd, nfkc or nfkd (UAX #15)
    let normalize(form:NormalForm):String { kv_ucd_normalize(&self, form as i32) }

    // the grapheme clusters, what a reader sees as characters (UAX #29):
    // each a String, so that for g in gs walks them, gs bound to it
    let graphemes:Array<String> {
        var at:String^
        var n:size_t = 0
        kv_ucd_graphemes(&self, &at, &n)
        var out:Array<String> = Array<String>()
        for i in 0..<n as i64 { out += at[i].copy() }
        kv_ucd_free_strings(at, n)
        return out
    }

    // the simple case mappings, one codepoint to one; fold is the case
    // folding, for comparing text whatever its case
    let upper():String { kv_ucd_upper(&self) }
    let lower():String { kv_ucd_lower(&self) }
    let fold():String { kv_ucd_fold(&self) }
}

extend uchr {
    let category:cstr { kv_ucd_category(self.utf32) }            // the general category, "Lu", "Nd", ...
    let name:String { kv_ucd_name_of(self.utf32) }               // "LATIN SMALL LETTER E WITH ACUTE", "" where none
    let combining:i64 { kv_ucd_combining(self.utf32) as i64 }     // the canonical combining class, 0 for a starter
    let upper:uchr { uchr(kv_ucd_to_upper(self.utf32)) }
    let lower:uchr { uchr(kv_ucd_to_lower(self.utf32)) }
    let fold:uchr { uchr(kv_ucd_to_fold(self.utf32)) }
    let decomposition:String { kv_ucd_decomposition(self.utf32, false) }      // the canonical decomposition, "" where none
    let compatibility:String { kv_ucd_decomposition(self.utf32, true) }       // with the compatibility ones
    let isLetter:bool { kv_ucd_category_index(self.utf32) >= 1 && kv_ucd_category_index(self.utf32) <= 5 }
    let isMark:bool { kv_ucd_category_index(self.utf32) >= 6 && kv_ucd_category_index(self.utf32) <= 8 }
    let isNumber:bool { kv_ucd_category_index(self.utf32) >= 9 && kv_ucd_category_index(self.utf32) <= 11 }
    let isPunctuation:bool { kv_ucd_category_index(self.utf32) >= 12 && kv_ucd_category_index(self.utf32) <= 18 }
    let isSymbol:bool { kv_ucd_category_index(self.utf32) >= 19 && kv_ucd_category_index(self.utf32) <= 22 }
    let isSpace:bool { kv_ucd_category_index(self.utf32) >= 23 && kv_ucd_category_index(self.utf32) <= 25 }
    let script:cstr { kv_ucd_script_name(kv_ucd_script(self.utf32)) }   // "Latin", "Han", "Common", ... (#157)
    // a binary property by its name, "Alphabetic", "White_Space", "Emoji", ...; false for a name there is none of
    let hasProperty(name:cstr):bool { kv_ucd_has_property(self.utf32, kv_ucd_property_id(name)) }
}
