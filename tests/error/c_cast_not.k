// error: C casts are not Kelvin: write 'v as T', or 'T(v)' for a built-in type
#import <stdio.h> as C
f(x:i32, n:size_t, p:i32^) {
    var y:i32 = (int32_t)!x;
}
