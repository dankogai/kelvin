// error: no function 'sqrt' is (f64):f64: C's function of the name is not taken where a Kelvin function has it (#223)
#import <math.h> as C
struct vec { x: float64; y: float64 }
let sqrt(v:vec):float64 { 0.0 }

let main():int32 {
    let root:(float64):float64 := sqrt
    println(root(4.0))
    return 0
}
