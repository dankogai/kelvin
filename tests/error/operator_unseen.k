// where only C sees that abs gives an int, which two operators take
// alike, C's _Generic says so (#42)
#import <stdlib.h> as C
struct vec { x: float64; y: float64 }
let *(k:int64, v:vec):vec { (vec){float64(k) * v.x, float64(k) * v.y} }
let *(k:float64, v:vec):vec { (vec){k * v.x, k * v.y} }
let main():int32 {
    let v:vec = {1.0, 2.0}
    let w:vec = abs(-2) * v
    return 0
}
// error: kv_no_such_operator
