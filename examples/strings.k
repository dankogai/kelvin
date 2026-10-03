// C strings: cstr is u8^, a pointer steps with .next and .prev, C's
// <string.h> and <ctype.h> just work, and numbers have text properties.
#import <ctype.h> as C
#import <string.h> as C

// count the vowels by walking the string
vowels(var s:cstr):i64 {        // var: this copy of the pointer moves
    var n = 0;
    while s^ != 0 {
        if strchr("aeiouAEIOU", s^) != nullptr {
            n += 1;
        }
        s := s.next;
    }
    return n;
}

// reverse in place: two pointers meet in the middle
reverse(s:cstr) {
    if strlen(s) == 0 {
        return;
    }
    var lo:cstr := s;
    var hi:cstr := s + strlen(s) - 1;
    while lo < hi {
        let c:u8 = lo^;
        lo^ = hi^;
        hi^ = c;
        lo := lo.next;
        hi := hi.prev;
    }
}

main():i32 {
    var buf:u8[32];
    strcpy(buf, "Hello, Kelvin");
    println(buf, ": ", strlen(buf), " bytes, ", vowels(buf), " vowels");
    reverse(buf);
    println(buf);
    for i in 0..<strlen(buf) {
        buf[i] = toupper(buf[i]) as u8;
    }
    println(buf);

    let answer:i32 = 42;
    println(answer.cstr, " ", answer.hex, " ", answer.bin, " ", (255:u8).oct);
    return 0;
}
// out: Hello, Kelvin: 13 bytes, 4 vowels
// out: nivleK ,olleH
// out: NIVLEK ,OLLEH
// out: 42 +0x2a +0b101010 0o377
