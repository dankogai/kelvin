// error: declarations are written 'var name:type', as in 'var b:[size_t^](3)'
#import <stdio.h> as C
#import "include_types.h" as C
struct pt { x:int32; y:int32; };
let f(x:int32, n:size_t, q:size_t^, r:uint64) {
    size_t * b[3];
}
