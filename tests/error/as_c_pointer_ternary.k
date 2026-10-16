// error: pointer types are written with a postfix '^', as in 'i32^'
#import <stdio.h> as C
#import "include_types.h" as C
let f(x:int32, n:size_t, p:int32^, np:size_t^, vp:any^, c:bool) {
    var r:uint8^ := c ? p as uint8* : vp;
}
