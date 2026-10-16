// error: sizeof a type needs parentheses: sizeof(i32 const^)
#import <stdio.h> as C
#import "include_types.h" as C
struct pt { x:int32; y:int32; };
let f(x:int32, n:size_t, q:size_t^, var r:uint64) {
    r = sizeof int32 const^;
}
