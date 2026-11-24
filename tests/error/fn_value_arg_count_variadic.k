// a variadic function's value takes its parameters or more (#729, #740)
#import <stdio.h> as C
let main():int32 {
    let p:(cstr, ...):int32 := printf
    p()
    return 0
}
// error: this function, of type (cstr, ...):i32, takes 1 argument or more, and it is given 0
