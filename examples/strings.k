// C strings: cstr is u8^, for c in s walks one, a pointer steps with .next
// and .prev, C's <string.h> and <ctype.h> just work, and numbers have text
// properties.
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

// reverse in place: two pointers meet in the middle
let reverse(s:cstr) {
    if strlen(s) == 0 {
        return
    }
    var lo:cstr := s
    var hi:cstr := s + strlen(s) - 1
    while lo < hi {
        let c:u8 = lo^
        lo^ = hi^
        hi^ = c
        lo := lo.next
        hi := hi.prev
    }
}

let main():i32 {
    var buf:u8[32]
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
