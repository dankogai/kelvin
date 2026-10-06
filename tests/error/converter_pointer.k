// error: converters are only for built-in types like u8(v); for other types write 'v as T'
#import <stdio.h> as C
struct pt { x:i32; y:i32; };
let f(x:i32, n:size_t, p:i32^, d:f64, vp:any^):i32 {
    var s:u8^ := u8^(vp);
    return 0;
}
