#import <stdio.h> as C
#import <stdlib.h> as C

let main():int32 {
    // converters: T(v) for built-in types, with C's conversion semantics
    printf("%d %d %.1f %d\n", int32(3.9), uint8(300), float64(7) / 2, bool(5));

    // v as T for any type; malloc(...) as T is the typical use
    var p:int32^ := malloc(3 * sizeof(int32)) as int32^;
    p[0] = 10; p[1] = 20; p[2] = 30;
    var bytes:uint8^ := p as uint8^;
    printf("%d %d\n", (p as int32^)[2], int32(bytes[0] == 10 || bytes[3] == 10));
    free(p as any^);

    // `as` binds tighter than binary operators, looser than prefix ones
    var x:int32 = 1;
    printf("%d\n", -x as uint8);                  // (-x) as u8 = 255
    var a:int32 = 100000, b:int32 = 100000;
    printf("%d\n", a * b as int64 == 10000000000);  // a * (b as i64): no i32 overflow
    printf("%d\n", x as int64 as int32);           // chains left to right

    // C typedef names work after `as`
    var n:size_t = 5 as size_t;
    printf("%d\n", int32(n * 2));

    // converters nest inside parentheses and sizeof
    printf("%d %d\n", (int32(2.5) + 1), int32(sizeof(int64(x))));
    return 0;
}
// out: 3 44 3.5 1
// out: 30 1
// out: 255
// out: 1
// out: 1
// out: 10
// out: 3 8
