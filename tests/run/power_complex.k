// z ** w (#380) of <math>'s c64 and c32, pow's, with an f64 or an f32 on
// either side; of C's _Complex, cpow; x **= y
#import <math>
#import <complex.h> as C
#inline C {
static double _Complex cmk(double r, double i) { return r + i * I; }
static double cre(double _Complex z) { return creal(z); }
static double cim(double _Complex z) { return cimag(z); }
}
let cmk(r:f64, i:f64):f64 _Complex
let cre(z:f64 _Complex):f64
let cim(z:f64 _Complex):f64
let main():int32 {
    let i = c64(0.0, 1.0)
    let z = c64(1.0, 1.0)
    println(i ** i, " ", 2.0 ** i, " ", z ** z)
    let h:c32 = c32(z)
    println(h ** h)
    var w = z
    w **= 2.0
    println(abs(w - c64(0.0, 2.0)) < 1e-15, " ", abs(z ** 2 - c64(0.0, 2.0)) < 1e-15)
    let cc:f64 _Complex = cmk(1.0, 1.0)
    let p = cc ** cc
    println(cre(p), " ", cim(p))
    return 0
}
// out: {real: 0.20787957635076193, imag: 0.0} {real: 0.76923890136397211, imag: 0.63896127631363475} {real: 0.27395725383012109, imag: 0.58370075875861471}
// out: {real: 0.273957253, imag: 0.583700776}
// out: true true
// out: 0.27395725383012109 0.58370075875861471
