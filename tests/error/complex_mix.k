// complex32 and complex64 do not mix: convert one (#43)
#import <lib/complex.k>
main():i32 {
    let z:complex64 = complex64(1.0, 2.0)
    let h:complex32 = complex32(1.0:f32, 2.0:f32)
    let s:complex64 = z + h
    return 0
}
// error: no operator + takes complex64 and complex32
