// numbers from text (#36): T(text), T(text, base) and text.T, read as C's
// strtol and strtod read them, clamped to the type's limits
#import <errno.h> as C
#import <stdlib.h> as C
#import <string.h> as C
#import "include/fields.h" as C

let answer:cstr := "42"
let twice(n:i64):i64 { n * 2 }
// a number read from text is no text in the function's buffer
let from_hex(n:i64):i64 { i64(n.hex, 16) }

let main():i32 {
    // literals, cstr and u8 arrays; a base, and Kelvin's own prefixes
    var digits:[u8](4) = ['7', '5', '5', 0]
    println(i64("42"), " ", i32(answer), " ", u16(digits), " ", i32("755", 8), " ", i64("ff", 16), " ",
            u8("101", 2))
    println(i64("-0x1f", 16), " ", i64("0o17", 8), " ", i64("0b11", 2), " ", i64("  +12"), " ", i64("0755"))

    // the longest number is taken; no number is 0
    println(i64("42abc"), " ", i64("abc"), " ", i64(""), " ", i64("- 5"), " ", i64("--5"), " ", i64(nullptr as cstr))

    // out of range clamps to the type's limits, with errno set
    errno = 0
    let small:i8 = i8("300")
    let big_errno = errno == ERANGE
    println(small, " ", i8("-300"), " ", u8("-1"), " ", u8("256"), " ", big_errno)
    println(i64("9223372036854775807"), " ", i64("-9223372036854775808"), " ", i64("99999999999999999999"), " ",
            u64("18446744073709551615"))

    // floats, as strtod reads them, hex floats included
    let half:f64 = 0.5
    println(f64("1.5"), " ", f32("2.25"), " ", f64("1e3"), " ", f64("0x1.8p1"), " ", f64(half.hex) == half)

    // text.T is T(text), and a number's .T converts it
    let n:i64 = 255
    println("42".i64 + 1, " ", answer.u8, " ", "2.5".f64 * 2, " ", 300.u8, " ", n.hex.i64 == 0, " ",
            i64(n.hex, 16), " ", i64(n.oct, 8), " ", i64(n.bin, 2))

    // what kelvinc cannot see: C's _Generic reads text and converts numbers
    let env:cstr := getenv("KELVIN_TEXT_NUMBERS_UNSET")
    println(i64(strchr("x42", '4')), " ", i32(strlen("hello")), " ", f64(atoi("7")), " ", i64(env == nullptr))
    let base:i32 = 16
    println(i32(strchr("=7f", '7'), base), " ", twice(i64("21")), " ", from_hex(-77))

    // a C struct's field named like a type is the field
    var f:struct fields = {9, 8}
    println(f.i64, " ", f.u8)
    return 0
}
// out: 42 42 755 493 255 5
// out: -31 15 3 12 755
// out: 42 0 0 0 0 0
// out: 127 -128 0 255 true
// out: 9223372036854775807 -9223372036854775808 9223372036854775807 18446744073709551615
// out: 1.5 2.25 1000.0 3.0 true
// out: 43 42 5.0 44 true 255 255 255
// out: 42 5 7.0 1
// out: 127 42 -77
// out: 9 8
