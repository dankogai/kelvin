// error: pointer types are written with a postfix '^', as in 'i32^'
#import <stdio.h> as C
struct pt { x:int32; y:int32; };
let f(x:int32, n:size_t, p:int32^, d:float64, vp:any^):int32 {
    var q:int32^ := vp as int32*;
    return 0;
}
