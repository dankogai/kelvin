// #import <name> with no extension is <name.k> (#112): a Kelvin file of
// ./modules or of Kelvin's modules/
#import <math>
let main():int32 {
    let z:c64 = c64(1.0, 2.0)
    println(z.real, " ", z.imag, " ", abs(z) > 2.2)
    return 0
}
// out: 1.0 2.0 true
