// error: declarations are written 'var name:type', as in 'var r:size_t^^'
#import <stdio.h> as C
#import "include_types.h" as C
let f(x:int32, n:size_t, p:int32^, np:size_t^, vp:any^, c:bool) {
    size_t ** r = &np;
}
