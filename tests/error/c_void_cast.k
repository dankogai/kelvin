// error: C casts are not Kelvin: to discard a value, write it as a statement of its own
#import <stdio.h> as C
struct pt { x:int32; y:int32; };
let f(x:int32, n:size_t, p:int32^, d:float64, vp:any^):int32 {
    (void)x;
    return 0;
}
