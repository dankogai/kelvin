// error: c_cast_typedef_call.k:4:
#import <stdio.h> as C
let f(x:int32, n:size_t, p:int32^) {
    var y:size_t = (size_t)(n + 1);
}
