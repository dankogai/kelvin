// the prelude: print() and println() need no import (#17)
let main():int32 {
    println("Hello, Kelvin!");
    println();
    print("a", 1, "b");
    println();

    // every integer size prints portably, including i64 and 128-bit
    println(int8(-128), " ", uint8(255), " ", int16(-32768), " ", uint16(65535));
    println(-2147483648:int32, " ", 4294967295:uint32);
    println(-9223372036854775807:int64 - 1, " ", 18446744073709551615:uint64);
    var big:u128 = ~(0:u128);
    var small:i128 = -(big >> 1) - 1;
    println(big);
    println(small);

    // floats: every digit the type holds, with a point (#259)
    println(1.0, " ", 0.1, " ", -0.5, " ", 1.0 / 3, " ", 1e300, " ", 2.5e-8);
    println(0.1:float32, " ", 16777216:float32, " ", 1.0:float32 / 3);
    var zero:float64 = 0.0;
    println(zero / zero, " ", -(zero / zero), " ", 1 / zero, " ", -1 / zero);   // NaN's sign is not shown

    // bool, strings, null strings
    var ok:bool = true;
    var s:uint8^ := "bytes";
    var none:uint8^ := 0 as uint8^;
    println(ok, " ", bool(!ok), " ", !ok, " ", s, " ", none);   // !ok is a bool (#23)
    println(true, " ", false, " ", true + 1);                   // true is a bool

    // sixteen values in one call
    println(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16);

    // other pointers print as addresses
    var x = 42;
    var p:int64^ := &x;
    println(p != 0 as int64^);
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
// out: 1.0 0.10000000000000001 -0.5 0.33333333333333331 1.0000000000000001e+300 2.4999999999999999e-08
// out: 0.100000001 16777216.0 0.333333343
// out: nan nan inf -inf
// out: true false false bytes nullptr
// out: true false 2
// out: 12345678910111213141516
// out: true
