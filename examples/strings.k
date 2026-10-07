// C strings: cstr is immutable text, for c in s walks one, a u8^ cursor
// steps with p++ and p-- and may write, C's <string.h> and <ctype.h> just
// work, and numbers have text properties.
#import <ctype.h> as C
#import <string.h> as C

// count the vowels: for c in s walks the string up to its NUL
let vowels(s:cstr):i64 {
    var n = 0
    for c in s {
        if strchr("aeiouAEIOU", c) != nullptr {
            n += 1
        }
    }
    return n
}

// reverse in place: a cstr cannot change, so the text comes as u8^, and
// two cursors meet in the middle
let reverse(s:u8^) {
    if strlen(s) == 0 {
        return
    }
    var lo:u8^ := s
    var hi:u8^ := &s[strlen(s) - 1]
    while lo < hi {
        let c:u8 = lo^
        lo^ = hi^
        hi^ = c
        lo++
        hi--
    }
}

let main():i32 {
    var buf:[u8](32)
    strcpy(buf, "Hello, Kelvin")
    println(buf, ": ", strlen(buf), " bytes, ", vowels(buf), " vowels")
    reverse(buf)
    println(buf)
    for i in 0..<strlen(buf) {
        buf[i] = toupper(buf[i]) as u8
    }
    println(buf)

    let answer:i32 = 42
    println(answer.cstr, " ", answer.hex, " ", answer.bin, " ", (255:u8).oct)
    return 0
}
// out: Hello, Kelvin: 13 bytes, 4 vowels
// out: nivleK ,olleH
// out: NIVLEK ,OLLEH
// out: 42 +0x2a +0b101010 0o377
