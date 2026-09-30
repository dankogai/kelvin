#import <stdio.h> as C
#import <stdlib.h> as C

main(): i32
{
    // converters: T(v) for built-in types, with C's conversion semantics
    printf("%d %d %.1f %d\n", i32(3.9), u8(300), f64(7) / 2, bool(5));

    // v as T for any type; malloc(...) as T is the typical use
    var p: i32^ = malloc(3 * sizeof(i32)) as i32^;
    p[0] = 10; p[1] = 20; p[2] = 30;
    var bytes: u8^ = p as u8^;
    printf("%d %d\n", (p as i32^)[2], i32(bytes[0] == 10 || bytes[3] == 10));
    free(p as void^);

    // `as` binds tighter than binary operators, looser than prefix ones
    var x: i32 = 1;
    printf("%d\n", -x as u8);                  // (-x) as u8 = 255
    var a: i32 = 100000, b: i32 = 100000;
    printf("%d\n", a * b as i64 == 10000000000);  // a * (b as i64): no i32 overflow
    printf("%d\n", x as i64 as i32);           // chains left to right

    // C typedef names work after `as`
    var n: size_t = 5 as size_t;
    printf("%d\n", i32(n * 2));

    // converters nest inside parentheses and sizeof
    printf("%d %d\n", (i32(2.5) + 1), i32(sizeof(i64(x))));

    x as void;                                 // C's (void)x
    return 0;
}
// out: 3 44 3.5 1
// out: 30 1
// out: 255
// out: 1
// out: 1
// out: 10
// out: 3 8
