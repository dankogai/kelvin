// T(v) of a number is a converter, never C's cast (#513): the nearest value
// T holds, as text's is: an integer past T's range is T's limit, a float
// truncated toward zero, past T's range its limit, NaN 0; a narrower float
// past its range an infinity; a global's value stays C's constant; and
// BigInt's i64(b) and b.i64 alike; `v as T` stays C's, which wraps
let big:i64 = i64(1e30)
let small:u8 = u8(300)
let main():int32 {
    let n:i64 = 300
    let d = -3.9
    let nan = 0.0 / 0.0
    let u:u64 = 18446744073709551615 as u64
    println(u8(n), " ", i8(-200), " ", u64(-1), " ", i64(1e30), " ", i32(3.9), " ", i32(d), " ", i64(nan), " ", u8(u))
    println(i64(u), " ", u32(n), " ", i16(70000), " ", big, " ", small, " ", f32(1e300), " ", f64(n), " ", bool(n))
    println(u8(255), " ", i64(i32(7)), " ", 300.uint8, " ", u8("300"), " ", 300 as u8, " ", n as u8, " ", u128(-1), " ", i128(1e40))
    let b = 1n << 1024
    println(i64(b), " ", b.i64, " ", i64(-b), " ", u64(b), " ", u64(-5n), " ", (2n ** 64 - 1).u64, " ", i64(42n))
    return 0
}
// out: 255 -128 0 9223372036854775807 3 -3 0 255
// out: 9223372036854775807 300 32767 9223372036854775807 255 inf 300.0 true
// out: 255 7 255 255 44 44 0 170141183460469231731687303715884105727
// out: 9223372036854775807 9223372036854775807 -9223372036854775808 18446744073709551615 0 18446744073709551615 42
