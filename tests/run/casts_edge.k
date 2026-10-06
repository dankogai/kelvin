// regressions from the review of change #14
#import <stdio.h> as C
#import <stdlib.h> as C

let twice(v:i32):i32 { return v * 2; }

let main():i32 {
    var x:i32 = 3;
    var n:size_t = 2;

    // `*` after the type of `as` is multiplication
    printf("%d\n", x as i64 * 2 == 6);
    var r:i32^ := malloc(n as size_t * sizeof(i32)) as i32^;
    r[1] = 7;
    printf("%d\n", r[1]);
    free(r as any^);

    // statements may start with a converter
    u8(x) == 0 ? println("zero") : println("not zero");

    // compound literals: built-in types, typedef names, and under sizeof
    var d:div_t = (div_t){.quot = 3, .rem = 1};
    printf("%d %d\n", d.quot, d.rem);
    printf("%d\n", i32(sizeof ([i32](3))[1, 2, 3]));
    printf("%d\n", ([i32](2))[5, 6][1]);

    // parenthesized names still behave as expressions
    printf("%d %d\n", (x) - 1, (twice)(x));
    printf("%d\n", i32(sizeof(size_t)));
    return 0;
}
// out: 1
// out: 7
// out: not zero
// out: 3 1
// out: 12
// out: 6
// out: 2 6
// out: 8
