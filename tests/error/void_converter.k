// error: 'void' is not a Kelvin type; use any^ for C's void *
#import <stdio.h> as C
f(x:i32, n:size_t, p:i32^) {
    void(x);
}
