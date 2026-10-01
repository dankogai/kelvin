// error: declarations are written 'name: type', as in 's: const u8^'
#import <stdio.h> as C
#import "include_types.h" as C
struct pt { x: i32; y: i32; };
f(x: i32, n: size_t, q: size_t^, r: u64)
{
    const u8 * s = "hi";
}
