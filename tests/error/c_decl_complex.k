// error: '_Complex' is C99's complex type, left out on purpose: #import <math> and write c64 or c32, Kelvin's own
#import <stdio.h> as C
#import "include_types.h" as C
struct pt { x:int32; y:int32; };
let f(x:int32, n:size_t, q:size_t^, r:uint64) {
    float64 _Complex z = 1;
}
