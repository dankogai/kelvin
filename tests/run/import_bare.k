// #import <name> with no extension is <name.k> (#112): a Kelvin file of
// ./modules or of Kelvin's modules/
#import <complex>
let main():i32 {
    let z:complex64 = complex64(1.0, 2.0)
    println(z.real, " ", z.imag, " ", abs(z) > 2.2)
    return 0
}
// out: 1.0 2.0 true
