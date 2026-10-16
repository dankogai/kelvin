// numbers from text (#36), from review: errno, run-time bases, NULL,
// i8 text, text properties, C's text types, ?: of texts, 128 bits, and
// C fields named like Kelvin's types
#import <errno.h> as C
#import <stdint.h> as C
#import <stdlib.h> as C
#import "include/texts.h" as C

// a number kelvinc cannot see stays a constant at file scope
let big = uint64(UINT32_MAX)

let main(argc:int32, argv:uint8^^):int32 {
    // errno is ERANGE after every clamp, and left alone otherwise
    errno = EDOM
    let a = int64("42")
    let kept = errno == EDOM
    errno = 0
    let low = int8("-300")
    let e1 = errno == ERANGE
    errno = 0
    let neg = uint8("-1")
    let e2 = errno == ERANGE
    errno = 0
    let high = uint8("256")
    let e3 = errno == ERANGE
    println(a, " ", kept, " ", low, " ", e1, " ", neg, " ", e2, " ", high, " ", e3)

    // a base outside 2 to 36 at run time, a NULL text, and a written octal base
    var base:int64 = 0
    let b0 = int32("0x10", base)
    base = 37
    let b37 = int32("10", base)
    base = atol("4294967304")
    let wide = int32("777", base)
    println(b0, " ", b37, " ", wide, " ", float64(nullptr as cstr), " ", float32(nullptr as cstr), " ", int32("777", 010))

    // i8 text, and the text of properties
    var t:[int8](3) = ['4', '2', 0]
    let tp:int8^ := &t[0]
    let n:int64 = 5
    let x:float64 = 2.5
    println(int64(t), " ", int64(tp), " ", int64(n.dec), " ", int64(n.cstr), " ", float64(x.cstr), " ", float64(x.hex) == x)

    // C's text types kelvinc cannot see: _Generic reads them
    let v:xmlChar^ := get_prop()
    var name:[gchar](8) = ['2', '3', 0]
    println(int64(column_text()), " ", int64(const_text()), " ", int64(signed_text()), " ", int64(unsigned_text()), " ",
            int64(v), " ", int64(get_str()), " ", int64(name), " ", float64(name))

    // a ?: of texts of different C types, and an unseen value nested
    let fallback:cstr := "8"
    println(int32(argc > 1 ? argv[1] : fallback), " ", int64(labs(int64(labs(int64(atol("-12")))))), " ", big)

    // 128 bits
    let max = i128("170141183460469231731687303715884105727")
    println(max > 0 && i128("999999999999999999999999999999999999999") == max, " ", i128("-0x10", 16), " ",
            u128("ff", 16), " ", "12".i128, " ", u128("-1"), " ", i128(getenv("KELVIN_UNSET")))

    // bool reads no text: of a pointer, it tells nullptr apart; a
    // volatile u8^ is no text either, as C's volatile char * is not
    let missing:cstr := getenv("KELVIN_UNSET")
    var digits:[uint8](3) = ['4', '2', 0]
    let vp:volatile uint8^ := &digits[0]
    println(bool(missing), " ", bool(fallback), " ", int64(vp) == vp as int64)

    // fields named like types win where the receiver may be a C struct
    var o:object = make_object(-42)
    let op:object^ := &o
    var tf:tfields = {9, 8}
    var u:object_union = {.int64 = 5}
    println(o.via.int64, " ", op^.via.int64, " ", make_object(7).via.int64, " ", tf.int64, " ", tf.uint8, " ", u.int64)
    o.via.float64 = 1.5
    println(o.via.float64)
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
