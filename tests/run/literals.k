#import <stdio.h> as C

let main():int32 {
    var val:uint64 = 10;              // C: 10UL
    var f:float32 = 1.5;               // C: 1.5f
    var big:uint64 = 0xffffffffffffffff;
    var mask:uint32 = 0xff;           // hex digits a-f are not suffixes
    var flag:bool = true;          // not inferred: bool is written
    var e = 1e3;                    // f64
    var h = 0x1p4;                  // f64 (hex float)
    var b = 0b101;                  // i64
    var o = 017;                    // i64, octal as in C
    var one:uint64 = 1;
    printf("%d %.1f %d %d %d\n", int32(val), f, big == 0xffffffffffffffff, int32(mask), flag);
    printf("%.0f %.0f %d %d\n", e, h, int32(b), int32(o));
    printf("%d %d\n", int32(sizeof f), int32((one << 40) >> 40));
    return 0;
}
// out: 10 1.5 1 255 1
// out: 1000 16 5 15
// out: 4 1
