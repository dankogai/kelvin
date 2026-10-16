// error: c_cast_typeof.k:5:
#import <stdio.h> as C
struct pt { x:int32; y:int32; };
let f(x:int32, n:size_t, p:int32^, d:float64, vp:any^):int32 {
    var a:uint64 = (__typeof__(x))-1;
    return 0;
}
