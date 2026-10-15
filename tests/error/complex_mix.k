// c32 and c64 do not mix: convert one (#43)
#import <math>
let main():i32 {
    let z:c64 = c64(1.0, 2.0)
    let h:c32 = c32(1.0:f32, 2.0:f32)
    let s:c64 = z + h
    return 0
}
// error: no operator + takes c64 and c32
