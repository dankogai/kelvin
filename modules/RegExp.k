// modules/RegExp.k - regular expressions (#157), JS's with the u flag, over
// Kelvin's Strings: `$/pattern/flags` is a literal, read where this module is
// imported, and RegExp.compile(pattern, flags) the same from text. Written in
// Kelvin over libkRegExp, runtime/regexp.c, with libkUnicodeData under it for
// \p{...}, the case folding of the i flag and \X, a grapheme cluster; built by
// kelvinc --lib into RegExp.kh and the library that #import <RegExp> links.
//
//     #import <RegExp>
//     let re = $/(\d{4})-(?<month>\d\d)/g        // or RegExp("(\\d{4})-(?<month>\\d\\d)", "g")
//     var s = $"2026-10-17 and 2027-01-02"
//     println(re.test(&s))                              // true
//     var ms = s.match(&re)                             // every match, with the g flag
//     for m in ms { println(m[0], " ", m[1], " ", m["month"], " ", m.start) }
//     var t = s.replace(&re, "$<month>/$1")             // "10/2026 and 01/2027"
//     var parts = s.split(&$/\s+/)                      // hmm: bind the literal first
#import <kRegExp.h> as C
#import <string.h> as C
#import <UnicodeData>

// the engine's functions, by their C names
let rx_compile(pattern:cstr, flags:cstr):Bytes
let rx_groups(prog:const Bytes^):i64
let rx_group_name(prog:const Bytes^, i:i64):cstr
let rx_group_named(prog:const Bytes^, name:cstr):i64
let rx_flag(prog:const Bytes^, flag:u8):bool
let rx_search(prog:const Bytes^, s:const String^, from:i64, sticky:bool, caps:i64^):bool
let rx_expand(prog:const Bytes^, s:const String^, caps:const i64^, with:cstr, out:String^):()
let rx_escape(prog:const Bytes^, s:const String^):String
let rx_unescape(prog:const Bytes^, s:const String^):String
let rx_escape_bytes(prog:const Bytes^, b:const Bytes^):String
let rx_unescape_bytes(prog:const Bytes^, text:const u8^, len:size_t):Bytes
let rx_slice(s:const String^, lo:i64, hi:i64):String
let rx_cp_index(s:const String^, byte:i64):i64
let rx_byte_index(s:const String^, cp:i64):i64
let rx_next(s:const String^, byte:i64):i64

// a compiled pattern: its program, an owner, with the text it came from
struct RegExp {
    program: Bytes
    source: String
    flags: String
}

// one match: the text of the whole and of each group, "" where a group took
// no part, their codepoint offsets, -1 where none, and the groups' names
struct Match {
    text: Array<String>
    at: Array<i64>
    names: Array<String>
}

extend RegExp {
    // RegExp.compile("a+", "gi"), what $/a+/gi is; a pattern that is not
    // one ends the program, saying what is wrong and where
    static let compile(pattern:cstr, flags:cstr):Self {
        var re:Self = {.program = rx_compile(pattern, flags), .source = String(pattern), .flags = String(flags)}
        return re
    }
    static let compile(pattern:const String^, flags:cstr):Self { Self.compile(pattern^.cstr, flags) }
    static let compile(pattern:cstr, flags:const String^):Self { Self.compile(pattern, flags^.cstr) }
    static let compile(pattern:const String^, flags:const String^):Self { Self.compile(pattern^.cstr, flags^.cstr) }

    let groups:i64 { rx_groups(&self.program) }               // the capturing groups
    let global:bool { rx_flag(&self.program, 'g') }
    let sticky:bool { rx_flag(&self.program, 'y') }
    let ignoreCase:bool { rx_flag(&self.program, 'i') }
    let multiline:bool { rx_flag(&self.program, 'm') }
    let dotAll:bool { rx_flag(&self.program, 's') }

    // the match found from byte offset from, as a Match
    static let matchAt(re:const RegExp^, s:const String^, caps:const i64^):Match {
        var m:Match = {.text = Array<String>(), .at = Array<i64>(), .names = Array<String>()}
        let n:i64 = rx_groups(&re^.program) + 1
        for g in 0..<n {
            let lo = caps[2 * g]
            let hi = caps[2 * g + 1]
            if lo < 0 {
                m.text += String("")
                m.at += -1
                m.at += -1
            } else {
                m.text += rx_slice(s, lo, hi)
                m.at += rx_cp_index(s, lo)
                m.at += rx_cp_index(s, hi)
            }
            m.names += String(rx_group_name(&re^.program, g))
        }
        return m
    }

    // does s have a match? at its start alone with the y flag
    let test(s:const String^):bool {
        var caps:[i64](256)
        return rx_search(&self.program, s, 0, self.sticky, caps)
    }

    // the first match at or after codepoint from, or none
    let execFrom(s:const String^, from:i64):Match? {
        var caps:[i64](256)
        if !rx_search(&self.program, s, rx_byte_index(s, from), self.sticky, caps) { return none }
        return Self.matchAt(&self, s, caps)
    }

    // the first match, or none
    let exec(s:const String^):Match? { self.execFrom(s, 0) }

    // the codepoint offset of the first match, or -1
    let search(s:const String^):i64 {
        var caps:[i64](256)
        if !rx_search(&self.program, s, 0, self.sticky, caps) { return -1 }
        return rx_cp_index(s, caps[0])
    }

    // every match with the g flag, else the first alone: an Array of them
    let match(s:const String^):Array<Match> {
        var out:Array<Match> = Array<Match>()
        var caps:[i64](256)
        var from:i64 = 0
        while rx_search(&self.program, s, from, self.sticky, caps) {
            out += Self.matchAt(&self, s, caps)
            if !self.global { break }
            from = caps[1] > caps[0] ? caps[1] : rx_next(s, caps[1])   // an empty match moves on by one
            if caps[1] >= s^.bytes^.count as i64 && caps[1] == caps[0] { break }
        }
        return out
    }

    // f called with each match (the first alone without g), a Match it owns:
    // s.match(&re) { println($0.text[0]) }
    let match(s:const String^, f:(Match):()):() {
        var caps:[i64](256)
        var from:i64 = 0
        while rx_search(&self.program, s, from, self.sticky, caps) {
            f(Self.matchAt(&self, s, caps))
            if !self.global { break }
            from = caps[1] > caps[0] ? caps[1] : rx_next(s, caps[1])   // an empty match moves on by one
            if caps[1] >= s^.bytes^.count as i64 && caps[1] == caps[0] { break }
        }
    }

    // s with each match (the first alone without g) replaced by with, where
    // $& is the match, $1 and $<name> a group, $` and $' the text around, $$ a $
    let replace(s:const String^, with:cstr):String {
        var out = String("")
        var caps:[i64](256)
        var from:i64 = 0
        var copied:i64 = 0
        while from <= s^.bytes^.count as i64 && rx_search(&self.program, s, from, self.sticky, caps) {
            out += rx_slice(s, copied, caps[0])
            rx_expand(&self.program, s, caps, with, &out)
            copied = caps[1]
            if !self.global { break }
            if caps[1] > caps[0] {
                from = caps[1]
            } else {
                if caps[1] >= s^.bytes^.count as i64 { break }   // an empty match at the end: done
                from = rx_next(s, caps[1])
                out += rx_slice(s, caps[1], from)                // the codepoint it moves over
                copied = from
            }
        }
        out += rx_slice(s, copied, s^.bytes^.count as i64)
        return out
    }

    // the same with the replacement a String, borrowed: s.replace(&re, &with)
    let replace(s:const String^, with:const String^):String { self.replace(s, with^.cstr) }

    // s with each match (the first alone without g) replaced by what f gives
    // for it, a String of the Match, which f owns:
    // s.replace(&re) { $`${(f64($0.text[1]) - 32.0) * 5.0 / 9.0}C` }
    let replace(s:const String^, f:(Match):String):String {
        var out = String("")
        var caps:[i64](256)
        var from:i64 = 0
        var copied:i64 = 0
        while from <= s^.bytes^.count as i64 && rx_search(&self.program, s, from, self.sticky, caps) {
            out += rx_slice(s, copied, caps[0])
            out += f(Self.matchAt(&self, s, caps))
            copied = caps[1]
            if !self.global { break }
            if caps[1] > caps[0] {
                from = caps[1]
            } else {
                if caps[1] >= s^.bytes^.count as i64 { break }
                from = rx_next(s, caps[1])
                out += rx_slice(s, caps[1], from)
                copied = from
            }
        }
        out += rx_slice(s, copied, s^.bytes^.count as i64)
        return out
    }

    // s cut at each match, JS's split: the pieces between, an empty match
    // between codepoints
    let split(s:const String^):Array<String> {
        var out:Array<String> = Array<String>()
        var caps:[i64](256)
        let n = s^.bytes^.count as i64
        if n == 0 {
            if !rx_search(&self.program, s, 0, true, caps) { out += String("") }
        } else {
            var piece:i64 = 0
            var from:i64 = 0
            while from < n {
                if !rx_search(&self.program, s, from, true, caps) || (caps[1] == piece && caps[1] == caps[0]) {
                    from = rx_next(s, from)
                    continue
                }
                if caps[1] == caps[0] && caps[0] >= n { break }
                out += rx_slice(s, piece, caps[0])
                piece = caps[1]
                from = caps[1] > caps[0] ? caps[1] : rx_next(s, caps[1])
            }
            out += rx_slice(s, piece, n)
        }
        return out
    }

    // f called with each piece of s cut at the matches, a String it owns,
    // as split gives them: s.split(&re) { println($0) }
    let split(s:const String^, f:(String):()):() {
        var caps:[i64](256)
        let n = s^.bytes^.count as i64
        if n == 0 {
            if !rx_search(&self.program, s, 0, true, caps) { f(String("")) }
        } else {
            var piece:i64 = 0
            var from:i64 = 0
            while from < n {
                if !rx_search(&self.program, s, from, true, caps) || (caps[1] == piece && caps[1] == caps[0]) {
                    from = rx_next(s, from)
                    continue
                }
                if caps[1] == caps[0] && caps[0] >= n { break }
                f(rx_slice(s, piece, caps[0]))
                piece = caps[1]
                from = caps[1] > caps[0] ? caps[1] : rx_next(s, caps[1])
            }
            f(rx_slice(s, piece, n))
        }
    }
}

extend Match {
    let count:i64 { self.text.count as i64 }                   // the groups and the whole
    let start:i64 { self.at[0] }                               // the codepoint offset of the match
    let end:i64 { self.at[1] }
    let [](i:i64):String { self.text[i].copy() }               // the text of group i, 0 the whole
    let [](name:cstr):String {                                 // the text of a named group, "" where there is none
        for i in 0..<self.names.count {
            if strcmp(self.names[i].cstr, name) == 0 { return self.text[i].copy() }
        }
        return String("")
    }
    let has(i:i64):bool { self.at[2 * i] >= 0 }                // did group i take part?
    let startOf(i:i64):i64 { self.at[2 * i] }
    let endOf(i:i64):i64 { self.at[2 * i + 1] }
}

extend String {
    let test(re:const RegExp^):bool { re^.test(&self) }
    let match(re:const RegExp^):Array<Match> { re^.match(&self) }
    let match(re:const RegExp^, f:(Match):()):() { re^.match(&self, f) }
    let search(re:const RegExp^):i64 { re^.search(&self) }
    let replace(re:const RegExp^, with:cstr):String { re^.replace(&self, with) }
    let replace(re:const RegExp^, with:const String^):String { re^.replace(&self, with^.cstr) }
    let replace(re:const RegExp^, f:(Match):String):String { re^.replace(&self, f) }
    let split(re:const RegExp^):Array<String> { re^.split(&self) }
    let split(re:const RegExp^, f:(String):()):() { re^.split(&self, f) }
    // the text with what re matches escaped, each codepoint as \u{...}, and a
    // backslash as \\ (#164): s.escape(&re), or s.escape($/[\p{Emoji}]/) with
    // the literal moved in; s.escape() of the prelude escapes what is not ASCII
    let escape(re:const RegExp^):String { rx_escape(&re^.program, &self) }
    let escape(re:RegExp):String { rx_escape(&re.program, &self) }
    // the escapes read back where re matches alone (#165), each match as
    // s.unescape() reads the whole: s.unescape($/\\u\{1F[0-9A-F]+\}/g)
    let unescape(re:const RegExp^):String { rx_unescape(&re^.program, &self) }
    let unescape(re:RegExp):String { rx_unescape(&re.program, &self) }
}

extend Bytes {
    // the bytes as text, each byte that re matches as \xHH, and so every byte
    // that is not printable ASCII, since a String holds text (#168); a Bytes
    // is matched byte by byte, each byte the codepoint of its value, so that
    // \xHH and [\x80-\xFF] mean bytes: b.escape($/[\x80-\xFF]/)
    let escape(re:const RegExp^):String { rx_escape_bytes(&re^.program, &self) }
    let escape(re:RegExp):String { rx_escape_bytes(&re.program, &self) }

    // the bytes of the text, with the escapes read back where re matches the
    // text alone, as Bytes.unescape(text) reads the whole: Bytes.unescape(&s, &re)
    static let unescape(text:cstr, re:const RegExp^):Bytes { rx_unescape_bytes(&re^.program, text, text.count) }
    static let unescape(text:const String^, re:const RegExp^):Bytes { rx_unescape_bytes(&re^.program, text^.cstr, text^.bytes^.count) }
    static let unescape(text:cstr, re:RegExp):Bytes { rx_unescape_bytes(&re.program, text, text.count) }
    static let unescape(text:const String^, re:RegExp):Bytes { rx_unescape_bytes(&re.program, text^.cstr, text^.bytes^.count) }
}

// RegExp(pattern, flags), the pattern and the flags a cstr or a String
// borrowed, &s: the same as RegExp.compile (#162), and as $/pattern/flags
let RegExp(pattern:cstr, flags:cstr):RegExp { RegExp.compile(pattern, flags) }
let RegExp(pattern:const String^, flags:cstr):RegExp { RegExp.compile(pattern^.cstr, flags) }
let RegExp(pattern:cstr, flags:const String^):RegExp { RegExp.compile(pattern, flags^.cstr) }
let RegExp(pattern:const String^, flags:const String^):RegExp { RegExp.compile(pattern^.cstr, flags^.cstr) }
