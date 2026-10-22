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
