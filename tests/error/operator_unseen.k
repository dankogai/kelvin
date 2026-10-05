// where only C sees that abs gives an int, which two operators take
// alike, C's _Generic says so (#42)
#import <stdlib.h> as C
struct vec { x: f64; y: f64 }
*(k:i64, v:vec):vec { (vec){f64(k) * v.x, f64(k) * v.y} }
*(k:f64, v:vec):vec { (vec){k * v.x, k * v.y} }
main():i32 {
    let v:vec = {1.0, 2.0}
    let w:vec = abs(-2) * v
    return 0
}
// error: kv_no_such_operator
