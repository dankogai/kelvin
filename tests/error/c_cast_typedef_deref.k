// error: c_cast_typedef_deref.k:4:
#import <stdio.h> as C
let f(x:i32, n:size_t, p:i32^) {
    var y:int32 = (int32_t)*p;
}
