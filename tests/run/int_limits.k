// T.min and T.max of an integer type (#545), as Swift's: the least and
// the greatest value a T holds, a T, a constant; of i8 to i128 and u8 to
// u128, by either name of the type; (i64.max - 1) in parentheses is no
// C cast; a type attribute of the program's own of the name wins
static_assert(u8.max == 255, "u8.max")
static_assert(i128.max > 0 && i32.min < 0, "limits are constants")
let top:i64 = i64.max
let low = i8.min
extend u16 {
    static let max:Self = 7
}
let main():int32 {
    println(i8.min, " ", i8.max, " ", i16.min, " ", i16.max, " ", i32.min, " ", i32.max, " ", i64.min, " ", i64.max)
    println(u8.min, " ", u8.max, " ", u32.max, " ", u64.min, " ", u64.max)
    println(i128.min, " ", i128.max, " ", u128.min, " ", u128.max)
    println(int64.max, " ", uint8.max, " ", i64.max.typename, " ", u8.max.typename, " ", i128.min.typename, " ", u64.min.typename)
    let x = i32.max
    println(x.typename, " ", x, " ", top, " ", low, " ", low.typename, " ", u16.max, " ", u16.min)
    println(i64.max - 1, " ", i64.max.hex, " ", (u8.max as i64) + 1, " ", (i64.max - 1) / 2, " ", -i64.max)
    var xs:[u8](u8.max)
    println(xs.count, " ", i64.max > 0, " ", i64.min < 0, " ", `${i16.max}`)
    for i in i8.max - 2...i8.max { print(i, " ") }
    println()
    return 0
}
// out: -128 127 -32768 32767 -2147483648 2147483647 -9223372036854775808 9223372036854775807
// out: 0 255 4294967295 0 18446744073709551615
// out: -170141183460469231731687303715884105728 170141183460469231731687303715884105727 0 340282366920938463463374607431768211455
// out: 9223372036854775807 255 i64 u8 i128 u64
// out: i32 2147483647 9223372036854775807 -128 i8 7 0
// out: 9223372036854775806 +0x7fffffffffffffff 256 4611686018427387903 -9223372036854775807
// out: 255 true true 32767
// out: 125 126 127 
