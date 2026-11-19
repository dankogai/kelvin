// Strings: a String is Unicode text, an owner, whose elements are its
// graphemes, with its codepoints and its bytes beside them; the prelude
// changes its case and searches it with a RegExp, with no import. A cstr
// is C's text, immutable, which for walks byte by byte; a u8^ cursor
// steps with p++ and p-- and may write; and numbers have text properties.

// count the vowels: for c in s walks a cstr up to its NUL
let vowels(s:cstr):i64 {
    var n = 0
    for c in s {
        for v in "aeiouAEIOU" {
            if c == v { n += 1 }
        }
    }
    return n
}

// reverse in place: a cstr cannot change, so the text comes as u8^, and
// two cursors meet in the middle
let reverse(s:u8^):() {
    var lo:u8^ := s
    var hi:u8^ := s
    while hi^ != 0 { hi++ }                               // to its NUL
    if hi == lo { return }
    hi--
    while lo < hi {
        let c:u8 = lo^
        lo^ = hi^
        hi^ = c
        lo++
        hi--
    }
}

// a String reversed, a new one: by its graphemes, so that é and a flag,
// of two codepoints each, stay whole
let reversed(s:const String^):String {
    var r = $""
    for g in s^ { r = g + r }
    return r
}

let main():i32 {
    let hello:cstr := "Hello, Kelvin"
    var buf:[u8](32)
    for i in 0...hello.count { buf[i] = hello[i] }        // a copy that may change, its NUL too
    println(buf, ": ", hello.count, " bytes, ", vowels(buf), " vowels")
    reverse(buf)
    println(buf)
    for i in 0..<hello.count {
        if buf[i] >= 'a' && buf[i] <= 'z' { buf[i] -= 32 }
    }
    println(buf)

    let city = $"Zu\u{308}rich 🇨🇭 café"                   // u and a combining diaeresis, a flag of two letters
    println(city, ": ", city.count, " graphemes, ", city.codepoints.count, " codepoints, ", city.bytes^.count, " bytes")
    println(city[1], " ", city[7], " ", city[0..<6].upper(), " ", city.find("café"), " ", reversed(&city))
    println(city.split($/\s+/), " ", city.replace($/\s+/g, "_"), " ", city.normalize(nfc).codepoints.count)

    let answer:i32 = 42
    println(answer.cstr, " ", answer.hex, " ", answer.bin, " ", (255:u8).oct)
    return 0
}
// out: Hello, Kelvin: 13 bytes, 4 vowels
// out: nivleK ,olleH
// out: NIVLEK ,OLLEH
// out: Zürich 🇨🇭 café: 13 graphemes, 15 codepoints, 23 bytes
// out: ü 🇨🇭 ZÜRICH 9 éfac 🇨🇭 hcirüZ
// out: ["Zürich", "🇨🇭", "café"] Zürich_🇨🇭_café 14
// out: 42 +0x2a +0b101010 0o377
