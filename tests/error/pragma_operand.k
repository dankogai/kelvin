// error: _Pragma("...") is only allowed as a statement of its own
#import <stdio.h> as C
#import "include_types.h" as C
struct pt { x:int32; y:int32; };
let f(x:int32, n:size_t, q:size_t^, r:uint64) {
    var v:size_t = _Pragma("") * q;
}
