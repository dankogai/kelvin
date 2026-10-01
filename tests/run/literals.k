#import <stdio.h> as C

main(): i32
{
    val: u64 = 10;              // C: 10UL
    f: f32 = 1.5;               // C: 1.5f
    big: u64 = 0xffffffffffffffff;
    mask: u32 = 0xff;           // hex digits a-f are not suffixes
    flag: bool = true;          // not inferred: bool is written
    e = 1e3;                    // f64
    h = 0x1p4;                  // f64 (hex float)
    b = 0b101;                  // i64
    o = 017;                    // i64, octal as in C
    one: u64 = 1;
    printf("%d %.1f %d %d %d\n", i32(val), f, big == 0xffffffffffffffff, i32(mask), flag);
    printf("%.0f %.0f %d %d\n", e, h, i32(b), i32(o));
    printf("%d %d\n", i32(sizeof f), i32((one << 40) >> 40));
    return 0;
}
// out: 10 1.5 1 255 1
// out: 1000 16 5 15
// out: 4 1
