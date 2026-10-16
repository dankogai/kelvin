// regressions from the fourth review of change #14
#import <stdio.h> as C
#import <stdlib.h> as C

let sq(x:int32):int32 { return x * x; }
let say(s:cstr):bool { puts(s); return true; }
var table:[int32](4) = [1, 2, 3, 4];

let main():int32 {
    var n:int32 = 2, best:int32 = 0, flag:int32 = 1;
    var a:[int32](3) = [1, 2, 3];

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
    var z:int32^ := ([int32](sizeof table / sizeof table[0]))[0, 0, 0, 42];
    printf("%d\n", z[3]);

    // pragmas pass through as written; a case lists several values (#63)
    switch (n) {
    case 2, 3:
        puts("two");
        puts("three");
    default:
        break;
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
