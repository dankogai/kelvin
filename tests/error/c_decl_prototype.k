// error: functions are declared at the top level as 'let g(...):size_t'
#import <stdio.h> as C
#import "include_types.h" as C
struct pt { x:i32; y:i32; };
let f(x:i32, n:size_t, q:size_t^, r:u64) {
    size_t g(void);
}
