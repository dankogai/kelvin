// error: 'void' is not a Kelvin type; use any^ for C's void *
#import <stdio.h> as C
let f(x:int32, n:size_t, p:int32^) {
    void(x);
}
