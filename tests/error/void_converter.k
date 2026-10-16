// error: 'void' is not a Kelvin type; use any^ for C's void *
#import <stdio.h> as C
let f(x:int32, n:size_t, p:i32^) {
    void(x);
}
