// error: functions are declared at the top level as 'let g(...):size_t'
#import <stdio.h> as C
#import "include_types.h" as C
struct pt { x:int32; y:int32; };
let f(x:int32, n:size_t, q:size_t^, r:uint64) {
    size_t g(void);
}
