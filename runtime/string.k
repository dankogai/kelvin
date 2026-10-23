// runtime/string.k - a String's searching and trimming (#177), written in
// Kelvin (#289): kelvinc --runtime builds it into libkelvin, each kv_
// function by the name kelvin_prelude.h declares, which the C kelvinc
// writes calls. A function here cannot use what it implements, s.find
// in kv_string_find_ref, so these work on the bytes. The helpers are
// static, C's, so that no name of theirs meets a program's.
#import <string.h> as C

// the codepoint index of the n bytes at p in s, or -1: by the bytes,
// the index counted as the codepoints before it
static let find_bytes(s:const String^, p:const u8^, n:size_t):int64 {
    let at:cstr := s^.cstr
    let count:size_t = s^.bytes^.count
    if n > count { return -1 }
    var i:size_t = 0
    while i + n <= count {
        if memcmp(&at[i], p, n) == 0 {
            var k:int64 = 0
            for j in 0..<i {
                if (at[j] & 0xC0) != 0x80 { k += 1 }
            }
            return k
        }
        i += 1
    }
    return -1
}

// whether s starts, or ends, with the n bytes at p
static let starts_bytes(s:const String^, p:const u8^, n:size_t):bool {
    return n <= s^.bytes^.count && (n == 0 || memcmp(s^.cstr, p, n) == 0)
}

static let ends_bytes(s:const String^, p:const u8^, n:size_t):bool {
    let count:size_t = s^.bytes^.count
    return n <= count && (n == 0 || memcmp(&s^.cstr[count - n], p, n) == 0)
}

let kv_string_find_text(s:const String^, t:const any^):int64 { find_bytes(s, t as const u8^, strlen(t)) }
let kv_string_find_ref(s:const String^, t:const String^):int64 { find_bytes(s, t^.cstr, t^.bytes^.count) }
let kv_string_has_text(s:const String^, t:const any^):bool { kv_string_find_text(s, t) >= 0 }
let kv_string_has_ref(s:const String^, t:const String^):bool { kv_string_find_ref(s, t) >= 0 }
let kv_string_starts_text(s:const String^, t:const any^):bool { starts_bytes(s, t as const u8^, strlen(t)) }
let kv_string_starts_ref(s:const String^, t:const String^):bool { starts_bytes(s, t^.cstr, t^.bytes^.count) }
let kv_string_ends_text(s:const String^, t:const any^):bool { ends_bytes(s, t as const u8^, strlen(t)) }
let kv_string_ends_ref(s:const String^, t:const String^):bool { ends_bytes(s, t^.cstr, t^.bytes^.count) }

// a blank, as JS's \s has them, U+3000 among them
static let is_blank_cp(c:u32):bool {
    return c == 9 || c == 10 || c == 11 || c == 12 || c == 13 || c == 32 || c == 0xA0 || c == 0x1680 ||
        (c >= 0x2000 && c <= 0x200A) || c == 0x2028 || c == 0x2029 || c == 0x202F || c == 0x205F ||
        c == 0x3000 || c == 0xFEFF
}

// $"..." of a literal (#299): its n bytes, a NUL among them too, which
// C's sizeof counts and strlen does not; checked as UTF-8, as String(&b)
let kv_string_lit(p:const any^, n:size_t):String {
    let b = Bytes(p as const u8^, n)
    return String(&b)
}

// s.trim(): a new String of s without the blanks at either end
let kv_string_trim(s:const String^):String {
    var lo:int64 = -1
    var hi:int64 = 0
    var i:int64 = 0
    for c in s^ {
        if !is_blank_cp(c.utf32) {
            if lo < 0 { lo = i }
            hi = i + 1
        }
        i += 1
    }
    if lo < 0 { return $"" }
    return s^[lo..<hi]
}

// ---------- escape and unescape (#164) ----------

// v's hex digits, upper case, onto out
static let put_hex(out:String^, v:u32) {
    if v >= 16 { put_hex(out, v / 16) }
    let digits:cstr := "0123456789ABCDEF"
    out^ += (digits[v % 16] as u32).uchr
}

// s.escape(): the text with each codepoint beyond ASCII as \u{...}, a NUL
// as \u{0} (#299), and a backslash as \\, so that unescape reads it back,
// and a literal of it too: a String holds a NUL, which a cstr cannot
let kv_string_escape(s:const String^):String {
    var out = $""
    for c in s^ {
        let cp:u32 = c.utf32
        if cp == 0 {
            out += "\\u{0}"
        } else if cp == '\\' {
            out += "\\\\"
        } else if cp < 0x80 {
            out += c
        } else {
            out += "\\u{"
            put_hex(&out, cp)
            out += "}"
        }
    }
    return out
}

// a hex digit's value, or -1
static let hex_value(c:u32):int64 {
    if c >= '0' && c <= '9' { return (c - '0') as int64 }
    if c >= 'a' && c <= 'f' { return (c - 'a' + 10) as int64 }
    if c >= 'A' && c <= 'F' { return (c - 'A' + 10) as int64 }
    return -1
}

// the codepoint at i of cps, or 0 past the end, which no escape's is
static let cp_at(cps:const $[u32]^, i:int64):u32 {
    if i < cps^.count as int64 { return cps^[i] }
    return 0
}

// the n hex digits at i of cps, or -1
static let hex_run(cps:const $[u32]^, i:int64, n:int64):int64 {
    var v:int64 = 0
    for k in 0..<n {
        let h = hex_value(cp_at(cps, i + k))
        if h < 0 { return -1 }
        v = v * 16 + h
    }
    return v
}

// s.unescape(): \u{...}, \uHHHH (a surrogate pair joined), \xHH, \n, \r,
// \t, \0, \\, \" and \' read back; an escape that is none of these, or a
// codepoint that is not one, stays as written. Every character of an
// escape is ASCII, so the codepoints are read as the bytes were
let kv_string_unescape(s:const String^):String {
    var cps:$[u32] = $[]
    for c in s^ {
        cps += c.utf32                           // a NUL too (#299)
    }
    var out = $""
    let n = cps.count as int64
    var i:int64 = 0
    while i < n {
        if cps[i] != '\\' || i + 1 >= n {
            out += cps[i].uchr
            i += 1
            continue
        }
        let e:u32 = cps[i + 1]
        var cp:int64 = -1
        var next:int64 = i + 2
        if e == 'u' && cp_at(&cps, i + 2) == '{' {
            var q:int64 = i + 3
            var v:int64 = 0
            var digits = 0
            while hex_value(cp_at(&cps, q)) >= 0 && digits < 8 {
                v = v * 16 + hex_value(cp_at(&cps, q))
                q += 1
                digits += 1
            }
            if digits > 0 && cp_at(&cps, q) == '}' && v <= 0x10FFFF && !(v >= 0xD800 && v <= 0xDFFF) {
                cp = v
                next = q + 1
            }
        } else if e == 'u' {
            let v = hex_run(&cps, i + 2, 4)
            if v >= 0xD800 && v <= 0xDBFF && cp_at(&cps, i + 6) == '\\' && cp_at(&cps, i + 7) == 'u' {
                let lo = hex_run(&cps, i + 8, 4)
                if lo >= 0xDC00 && lo <= 0xDFFF {
                    cp = 0x10000 + (v - 0xD800) * 1024 + (lo - 0xDC00)
                    next = i + 12
                }
            } else if v >= 0 && !(v >= 0xD800 && v <= 0xDFFF) {
                cp = v
                next = i + 6
            }
        } else if e == 'x' {
            cp = hex_run(&cps, i + 2, 2)
            next = i + 4
        } else if e == 'n' {
            cp = 10
        } else if e == 'r' {
            cp = 13
        } else if e == 't' {
            cp = 9
        } else if e == '0' {
            cp = 0
        } else if e == '\\' || e == '"' || e == '\'' {
            cp = e as int64
        }
        if cp < 0 {                              // not an escape: the backslash as it is
            out += cps[i].uchr
            i += 1
            continue
        }
        out += (cp as u32).uchr
        i = next
    }
    return out
}
