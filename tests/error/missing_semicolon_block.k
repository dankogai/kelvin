// error: expected ';' or a new line before '{'
#import <stdio.h> as C
#import "include_types.h" as C
let f(x:int32, n:size_t, p:int32^, np:size_t^, vp:any^, c:bool) {
    var t:int32 = (x + 1) { x = 3; }
}
