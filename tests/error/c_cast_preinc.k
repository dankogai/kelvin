// error: C casts are not Kelvin: write 'v as T', or 'T(v)' for a built-in type
#import <stdio.h> as C
#import "include_types.h" as C
let f(var x:int32, n:size_t, p:int32^, np:size_t^, vp:any^, c:bool) {
    x = (size_t)++x;
}
