// error: pointer types are written with a postfix '^', as in '(i32^){0}'
#import <stdio.h> as C
#import "include_types.h" as C
struct pt { x:int32; y:int32; };
let f(x:int32, n:size_t, q:size_t^, r:uint64) {
    var w:size_t^^ := (size_t*){0};
}
