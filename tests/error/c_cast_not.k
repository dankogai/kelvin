// error: C casts are not Kelvin: write 'v as T', or 'T(v)' for a built-in type
#import <stdio.h> as C
let f(x:i32, n:size_t, p:i32^) {
    var y:int32 = (int32_t)!x;
}
