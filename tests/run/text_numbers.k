// numbers from text (#36): T(text), T(text, base) and text.T, read as C's
// strtol and strtod read them, clamped to the type's limits
#import <errno.h> as C
#import <stdlib.h> as C
#import <string.h> as C
#import "include/fields.h" as C

let answer:cstr := "42"
let twice(n:int64):int64 { n * 2 }
// a number read from text is no text in the function's buffer
let from_hex(n:int64):int64 { int64(n.hex, 16) }

let main():int32 {
    // literals, cstr and u8 arrays; a base, and Kelvin's own prefixes
    var digits:[uint8](4) = ['7', '5', '5', 0]
    println(int64("42"), " ", int32(answer), " ", uint16(digits), " ", int32("755", 8), " ", int64("ff", 16), " ",
            uint8("101", 2))
    println(int64("-0x1f", 16), " ", int64("0o17", 8), " ", int64("0b11", 2), " ", int64("  +12"), " ", int64("0755"))

    // the longest number is taken; no number is 0
    println(int64("42abc"), " ", int64("abc"), " ", int64(""), " ", int64("- 5"), " ", int64("--5"), " ", int64(nullptr as cstr))

    // out of range clamps to the type's limits, with errno set
    errno = 0
    let small:int8 = int8("300")
    let big_errno = errno == ERANGE
    println(small, " ", int8("-300"), " ", uint8("-1"), " ", uint8("256"), " ", big_errno)
    println(int64("9223372036854775807"), " ", int64("-9223372036854775808"), " ", int64("99999999999999999999"), " ",
            uint64("18446744073709551615"))

    // floats, as strtod reads them, hex floats included
    let half:float64 = 0.5
    println(float64("1.5"), " ", float32("2.25"), " ", float64("1e3"), " ", float64("0x1.8p1"), " ", float64(half.hex) == half)

    // text.T is T(text), and a number's .T converts it
    let n:int64 = 255
    println("42".int64 + 1, " ", answer.uint8, " ", "2.5".float64 * 2, " ", 300.uint8, " ", n.hex.int64 == 0, " ",
            int64(n.hex, 16), " ", int64(n.oct, 8), " ", int64(n.bin, 2))

    // what kelvinc cannot see: C's _Generic reads text and converts numbers
    let env:cstr := getenv("KELVIN_TEXT_NUMBERS_UNSET")
    println(int64(strchr("x42", '4')), " ", int32(strlen("hello")), " ", float64(atoi("7")), " ", int64(env == nullptr))
    let base:int32 = 16
    println(int32(strchr("=7f", '7'), base), " ", twice(int64("21")), " ", from_hex(-77))

    // a C struct's field named like a type is the field
    var f:struct fields = {9, 8}
    println(f.int64, " ", f.uint8)
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
