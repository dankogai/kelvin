// numbers from text (#36), from review: errno, run-time bases, NULL,
// i8 text, text properties, C's text types, ?: of texts, 128 bits, and
// C fields named like Kelvin's types
#import <errno.h> as C
#import <stdint.h> as C
#import <stdlib.h> as C
#import "include/texts.h" as C

// a number kelvinc cannot see stays a constant at file scope
let big = u64(UINT32_MAX)

main(argc:i32, argv:u8^^):i32 {
    // errno is ERANGE after every clamp, and left alone otherwise
    errno = EDOM
    let a = i64("42")
    let kept = errno == EDOM
    errno = 0
    let low = i8("-300")
    let e1 = errno == ERANGE
    errno = 0
    let neg = u8("-1")
    let e2 = errno == ERANGE
    errno = 0
    let high = u8("256")
    let e3 = errno == ERANGE
    println(a, " ", kept, " ", low, " ", e1, " ", neg, " ", e2, " ", high, " ", e3)

    // a base outside 2 to 36 at run time, a NULL text, and a written octal base
    var base:i64 = 0
    let b0 = i32("0x10", base)
    base = 37
    let b37 = i32("10", base)
    base = atol("4294967304")
    let wide = i32("777", base)
    println(b0, " ", b37, " ", wide, " ", f64(nullptr as cstr), " ", f32(nullptr as cstr), " ", i32("777", 010))

    // i8 text, and the text of properties
    var t:i8[3] = {'4', '2', 0}
    let tp:i8^ := &t[0]
    let n:i64 = 5
    let x:f64 = 2.5
    println(i64(t), " ", i64(tp), " ", i64(n.dec), " ", i64(n.cstr), " ", f64(x.cstr), " ", f64(x.hex) == x)

    // C's text types kelvinc cannot see: _Generic reads them
    let v:xmlChar^ := get_prop()
    var name:gchar[8] = {'2', '3', 0}
    println(i64(column_text()), " ", i64(const_text()), " ", i64(signed_text()), " ", i64(unsigned_text()), " ",
            i64(v), " ", i64(get_str()), " ", i64(name), " ", f64(name))

    // a ?: of texts of different C types, and an unseen value nested
    let fallback:cstr := "8"
    println(i32(argc > 1 ? argv[1] : fallback), " ", i64(labs(i64(labs(i64(atol("-12")))))), " ", big)

    // 128 bits
    let max = i128("170141183460469231731687303715884105727")
    println(max > 0 && i128("999999999999999999999999999999999999999") == max, " ", i128("-0x10", 16), " ",
            u128("ff", 16), " ", "12".i128, " ", u128("-1"), " ", i128(getenv("KELVIN_UNSET")))

    // bool reads no text: of a pointer, it tells nullptr apart; a
    // volatile u8^ is no text either, as C's volatile char * is not
    let missing:cstr := getenv("KELVIN_UNSET")
    var digits:u8[3] = {'4', '2', 0}
    let vp:volatile u8^ := &digits[0]
    println(bool(missing), " ", bool(fallback), " ", i64(vp) == vp as i64)

    // fields named like types win where the receiver may be a C struct
    var o:object = make_object(-42)
    let op:object^ := &o
    var tf:tfields = {9, 8}
    var u:object_union = {.i64 = 5}
    println(o.via.i64, " ", op^.via.i64, " ", make_object(7).via.i64, " ", tf.i64, " ", tf.u8, " ", u.i64)
    o.via.f64 = 1.5
    println(o.via.f64)
    return 0
}
// out: 42 true -128 true 0 true 255 true
// out: 0 0 0 0.0 0.0 511
// out: 42 42 5 5 2.5 true
// out: 31 32 33 34 42 17 23 23.0
// out: 8 12 4294967295
// out: true -16 255 12 0 0
// out: false true true
// out: -42 -42 7 9 8 5
// out: 1.5
