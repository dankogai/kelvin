// statements name(x) of names kelvinc does not see (#402): C's functions
// and macros, called as before under C's if (1), which a typedef there
// would make C's error; Kelvin's own functions, and print, are as written
#import <stdlib.h> as C
#import <stdio.h> as C
let twice(var n:i64):i64 { n *= 2; return n }
let main():i32 {
    var buf:u8^ := malloc(8) as u8^
    buf[0] = 'k'
    putchar(buf[0])
    putchar(10)
    free(buf)
    var n:i64 = 21
    twice(n)
    println(twice(n))
    return 0
}
// out: k
// out: 42
// c:     if (1) free(buf);
// c:     twice(n);
