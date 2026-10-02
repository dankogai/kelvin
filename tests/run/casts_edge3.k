// regressions from the fourth review of change #14
#import <stdio.h> as C
#import <stdlib.h> as C

sq(x: i32): i32 { return x * x; }
say(s: cstr): bool { puts(s); return true; }
var table: i32[4] = {1, 2, 3, 4};

main(): i32
{
    var n: i32 = 2, best: i32 = 0, flag: i32 = 1;
    var a: i32[3] = {1, 2, 3};

    // products whose values are used are expressions, not C declarations
    // (an XOR is converted, since || takes bools, #23)
    n * sq(3) == 18 || say("never");
    n * a[2] > best || say("never");
    if n * a[2] > best {
        best = n * a[2];
    }
    bool(flag ~ sq(1)) || say("xor");
    printf("best %d\n", best);

    // array sizes with subscripts inside compound literals
    var z: i32^ := (i32[sizeof table / sizeof table[0]]){0, 0, 0, 42};
    printf("%d\n", z[3]);

    // attributes and pragmas pass through as written
    switch (n) {
    case 2:
        puts("two");
        __attribute__((fallthrough));
    case 3:
        puts("three");
    }
    _Pragma("GCC diagnostic push");
    _Pragma("GCC diagnostic pop");
    return 0;
}
// out: xor
// out: best 6
// out: 42
// out: two
// out: three
