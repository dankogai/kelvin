// error: sizeof a type needs parentheses: sizeof(i32^)
#import <stdio.h> as C
#import "include_types.h" as C
let f(x:int32, n:size_t, p:int32^, np:size_t^, vp:any^, c:bool) {
    var z:uint64 = sizeof int32^;
}
