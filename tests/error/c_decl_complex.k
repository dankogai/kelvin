// error: declarations are written 'var name:type', as in 'var z:f64 _Complex'
#import <stdio.h> as C
#import "include_types.h" as C
struct pt { x:i32; y:i32; };
let f(x:i32, n:size_t, q:size_t^, r:u64) {
    f64 _Complex z = 1;
}
