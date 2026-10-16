// error: sizeof a type needs parentheses: sizeof(i32)
#import <stdio.h> as C
struct pt { x:int32; y:int32; };
let f(x:int32, n:size_t, p:int32^, d:float64, vp:any^):int32 {
    var z:uint64 = sizeof int32;
    return 0;
}
