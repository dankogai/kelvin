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
//     var e = $"é".codepoints[0]                 // 0xE9, a u32
//     println(gs.count, " ", e.name, " ", e.category)
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

// why codepoints make no String (#526): there are none, one is a
// surrogate, or one is no codepoint, past U+10FFFF or below 0
enum CodepointError { empty; surrogate: u32; outOfRange: i64 }

// the String of the n codepoints at cps, or of its first grapheme where one
// is true, the rest checked but dropped: what grapheme(c0, c1, ...) and
// String.fromCodepoints(c0, c1, ...) of integers are (#526)
let kv_codepoints_string(cps:const i64^, n:i64, one:bool):Result<String, CodepointError> {
    if n <= 0 { return err(CodepointError.empty) }
    for i in 0..<n {
        let c = cps[i]
        if c < 0 || c > 0x10FFFF { return err(CodepointError.outOfRange(c)) }
        if c >= 0xD800 && c <= 0xDFFF { return err(CodepointError.surrogate(c as u32)) }
    }
    var s = $""
    for i in 0..<n { s += cps[i] }
    if one { return s[0] }
    return s
}

// the same of an Array of codepoints
let kv_codepoints_array(cps:lent Array<u32>, one:bool):Result<String, CodepointError> {
    var xs = Array<i64>()
    for c in cps { xs += c as i64 }
    return kv_codepoints_string(xs.at, xs.count, one)
}

// the first grapheme of the codepoints, a String: grapheme(0x65, 0x301)
// is "é"; kelvinc and kelvin's kc read it of any number of integers
let grapheme(cps:lent Array<u32>):Result<String, CodepointError> { kv_codepoints_array(cps, true) }

extend String {
    // the String of the codepoints, all of them (#526)
    static let fromCodepoints(cps:lent Array<u32>):Result<String, CodepointError> { kv_codepoints_array(cps, false) }

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

    // the codepoints, each a u32 (#521, #527): for c in s.codepoints walks
    // them in place, with no Array made, which kelvinc and kc see
    let codepoints:Array<u32> {
        var out = Array<u32>()
        for c:u32 in self { out += c }
        return out
    }

    // the simple case mappings, one codepoint to one; fold is the case
    // folding, for comparing text whatever its case
    let upper():String { kv_ucd_upper(&self) }
    let lower():String { kv_ucd_lower(&self) }
    let fold():String { kv_ucd_fold(&self) }
}

// a codepoint's properties, on a u32 (#527), as s.codepoints gives them
extend u32 {
    let category:cstr { kv_ucd_category(self) }            // the general category, "Lu", "Nd", ...
    let name:String { kv_ucd_name_of(self) }               // "LATIN SMALL LETTER E WITH ACUTE", "" where none
    let combining:i64 { kv_ucd_combining(self) as i64 }     // the canonical combining class, 0 for a starter
    let upper:u32 { kv_ucd_to_upper(self) }
    let lower:u32 { kv_ucd_to_lower(self) }
    let fold:u32 { kv_ucd_to_fold(self) }
    let decomposition:String { kv_ucd_decomposition(self, false) }      // the canonical decomposition, "" where none
    let compatibility:String { kv_ucd_decomposition(self, true) }       // with the compatibility ones
    let isLetter:bool { kv_ucd_category_index(self) >= 1 && kv_ucd_category_index(self) <= 5 }
    let isMark:bool { kv_ucd_category_index(self) >= 6 && kv_ucd_category_index(self) <= 8 }
    let isNumber:bool { kv_ucd_category_index(self) >= 9 && kv_ucd_category_index(self) <= 11 }
    let isPunctuation:bool { kv_ucd_category_index(self) >= 12 && kv_ucd_category_index(self) <= 18 }
    let isSymbol:bool { kv_ucd_category_index(self) >= 19 && kv_ucd_category_index(self) <= 22 }
    let isSpace:bool { kv_ucd_category_index(self) >= 23 && kv_ucd_category_index(self) <= 25 }
    let script:cstr { kv_ucd_script_name(kv_ucd_script(self)) }   // "Latin", "Han", "Common", ... (#157)
    // a binary property by its name, "Alphabetic", "White_Space", "Emoji", ...; false for a name there is none of
    let hasProperty(name:cstr):bool { kv_ucd_has_property(self, kv_ucd_property_id(name)) }
}
