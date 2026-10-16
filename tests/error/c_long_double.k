// error: 'long' is not a Kelvin type, use f64 (long double has no Kelvin type yet)
#import <stdio.h> as C
struct pt { x:int32; y:int32; };
let f(x:int32, n:size_t, p:int32^, d:float64, vp:any^):int32 {
    var e:float64 = (long double)d;
    return 0;
}
