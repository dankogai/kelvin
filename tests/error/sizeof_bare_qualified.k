// error: sizeof a type needs parentheses: sizeof(i32 const^)
#import <stdio.h> as C
#import "include_types.h" as C
struct pt { x: i32; y: i32; };
f(x: i32, n: size_t, q: size_t^, var r: u64)
{
    r = sizeof i32 const^;
}
