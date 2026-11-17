// error: no function 'labs' is (i64):i64: C's function of the name is not taken where a Kelvin function has it (#223)
#import <stdlib.h> as C
struct vec { x: float64; y: float64 }
let labs(v:vec):int64 { 0 }

let main():int32 {
    let size:(int64):int64 := labs
    println(size(-4))
    return 0
}
