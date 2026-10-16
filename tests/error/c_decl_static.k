// error: declarations are written 'var name:type', as in 'static var m:size_t'
#import <stdio.h> as C
#import "include_types.h" as C
struct pt { x:int32; y:int32; };
let f(x:int32, n:size_t, q:size_t^, r:uint64) {
    static size_t m = 0;
}
