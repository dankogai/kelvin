// error: declarations are written 'var name:type', as in 'var q:size_t^'
#import <stdio.h> as C
struct pt { x:int32; y:int32; };
let f(x:int32, n:size_t, p:int32^, d:float64, vp:any^):int32 {
    size_t * q = &n;
    return 0;
}
