// error: converters are only for built-in types like u8(v); for other types write 'v as T'
#import <stdio.h> as C
struct pt { x:int32; y:int32; };
let f(x:int32, n:size_t, p:int32^, d:float64, vp:any^):int32 {
    var s:uint8^ := uint8^(vp);
    return 0;
}
