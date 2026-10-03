// error: '__extension__' is a C compiler keyword, not available in Kelvin
#import <stdio.h> as C
#import "include_types.h" as C
f(x:i32, n:size_t, p:i32^, np:size_t^, vp:any^, c:bool) {
    var y:i32 = __extension__ * p;
}
