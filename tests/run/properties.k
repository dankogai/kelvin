// properties (#21): .size is sizeof; .dec, .hex, .oct, .bin are text (u8^)
struct point { x:i32; y:i32; };
struct sized { size:u64; hex:i32; };       // fields win over properties

let main():i32 {
    var a:i8 = -1;
    var b:u8 = 255;
    var c:i32 = 42;
    var d:u64 = 18446744073709551615;
    var big:u128 = ~(0:u128);
    var e:i128 = -((big >> 1) as i128) - 1;      // i128's minimum
    println(a.dec, " ", a.hex, " ", a.oct, " ", a.bin);
    println(b.dec, " ", b.hex, " ", b.oct, " ", b.bin);
    println(c.dec, " ", c.hex, " ", (0:i32).dec, " ", (-c).hex);
    println(d.hex, " ", e.dec);
    println(42.hex, " ", 0xff.bin, " ", (7:u16).oct, " ", (c + 1).dec);

    var pi = 3.141592653589793;
    var f:f32 = 0.1;
    println(pi.dec, " ", pi.hex, " ", (-pi).hex, " ", f.dec, " ", f.hex);

    // .size is sizeof
    var p:struct point = {1, 2};
    var arr:[i32](10);
    var ptr:i32^;
    println(a.size, " ", c.size, " ", e.size, " ", pi.size, " ", p.size, " ", arr.size, " ", ptr.size, " ", c.size.dec);

    // a Kelvin struct's own fields named size or hex are fields
    var s:struct sized = {7, 9};
    println(s.size, " ", s.hex, " ", s.size.hex);

    // the text lives on the caller's stack for the rest of the block
    var t:u8^ := c.bin;
    println(t);
    return 0;
}
// out: -1 -0x1 -0o1 -0b1
// out: 255 0xff 0o377 0b11111111
// out: +42 +0x2a +0 -0x2a
// out: 0xffffffffffffffff -170141183460469231731687303715884105728
// out: +0x2a +0b11111111 0o7 +43
// out: +3.1415926535897931 +0x1.921fb54442d18p+1 -0x1.921fb54442d18p+1 +0.100000001 +0x1.99999ap-4
// out: 1 4 16 8 8 40 8 4
// out: 7 9 0x7
// out: +0b101010
