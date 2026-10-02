// the prelude: print() and println() need no import (#17)
main(): i32
{
    println("Hello, Kelvin!");
    println();
    print("a", 1, "b");
    println();

    // every integer size prints portably, including i64 and 128-bit
    println(i8(-128), " ", u8(255), " ", i16(-32768), " ", u16(65535));
    println(-2147483648:i32, " ", 4294967295:u32);
    println(-9223372036854775807:i64 - 1, " ", 18446744073709551615:u64);
    big: u128 = ~(0:u128);
    small: i128 = -(big >> 1) - 1;
    println(big);
    println(small);

    // floats: the shortest text that reads back the same, with a point
    println(1.0, " ", 0.1, " ", -0.5, " ", 1.0 / 3, " ", 1e300, " ", 2.5e-8);
    println(0.1:f32, " ", 16777216:f32, " ", 1.0:f32 / 3);
    zero: f64 = 0.0;
    println(zero / zero, " ", -(zero / zero), " ", 1 / zero, " ", -1 / zero);   // NaN's sign is not shown

    // bool, strings, null strings
    ok: bool = true;
    s: u8^ := "bytes";
    none: u8^ := 0 as u8^;
    println(ok, " ", bool(!ok), " ", !ok, " ", s, " ", none);   // !ok is a bool (#23)
    println(true, " ", false, " ", true + 1);                   // true is a bool

    // sixteen values in one call
    println(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16);

    // other pointers print as addresses
    x = 42;
    p: i64^ := &x;
    println(p != 0 as i64^);
    return 0;
}
// out: Hello, Kelvin!
// out: 
// out: a1b
// out: -128 255 -32768 65535
// out: -2147483648 4294967295
// out: -9223372036854775808 18446744073709551615
// out: 340282366920938463463374607431768211455
// out: -170141183460469231731687303715884105728
// out: 1.0 0.1 -0.5 0.3333333333333333 1e+300 2.5e-08
// out: 0.1 16777216.0 0.33333334
// out: nan nan inf -inf
// out: true false false bytes (null)
// out: true false 2
// out: 12345678910111213141516
// out: true
