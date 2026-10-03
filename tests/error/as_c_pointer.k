// error: pointer types are written with a postfix '^', as in 'i32^'
#import <stdio.h> as C
struct pt { x:i32; y:i32; };
f(x:i32, n:size_t, p:i32^, d:f64, vp:any^):i32 {
    var q:i32^ := vp as i32*;
    return 0;
}
