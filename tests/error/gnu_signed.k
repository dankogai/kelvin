// error: '__signed__' is a C compiler keyword, not available in Kelvin
#import <stdio.h> as C
#import "include_types.h" as C
struct pt { x:int32; y:int32; };
let f(x:int32, n:size_t, q:size_t^, r:uint64) {
    var s1:__signed__ = -1;
}
