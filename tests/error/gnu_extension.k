// error: '__extension__' is a C compiler keyword, not available in Kelvin
#import <stdio.h> as C
#import "include_types.h" as C
let f(x:int32, n:size_t, p:int32^, np:size_t^, vp:any^, c:bool) {
    var y:int32 = __extension__ * p;
}
