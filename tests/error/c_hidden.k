// error: abs takes vec here, and this is i64: C's function of the name is not called where a Kelvin function has it (#223)
#import <stdlib.h> as C
struct vec { x: int64; y: int64 }
let abs(v:vec):int64 { v.x + v.y }

let main():int32 {
    println(abs(-3))
    return 0
}
