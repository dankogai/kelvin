// error: declarations are written 'var name:type', as in 'var s:const u8^'
#import <stdio.h> as C
#import "include_types.h" as C
struct pt { x:int32; y:int32; };
let f(x:int32, n:size_t, q:size_t^, r:uint64) {
    const uint8 * s = "hi";
}
