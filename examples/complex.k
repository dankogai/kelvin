// Complex numbers from modules/math.k, c64 (complex64 by its alias): functions of one name for several
// types, with C's own for the numbers, and operators a struct defines.
#import <math>
#import <stdio.h> as C

let PI = 3.141592653589793

// x, with what rounding leaves around 0 shown as 0
let tidy(x:float64):float64 { fabs(x) < 5e-10 ? 0.0 : x }

let show(z:c64):() { printf("%.4f%+.4fi", tidy(z.real), tidy(z.imag)) }

// the roots of a z² + b z + c
let roots(a:c64, b:c64, c:c64, r:c64^, s:c64^):() {
    let d:c64 = sqrt(b * b - 4.0 * a * c)
    r^ = (-b + d) / (2.0 * a)
    s^ = (-b - d) / (2.0 * a)
}

let main():int32 {
    let i:c64 = c64(0.0, 1.0)

    // sin of a number is C's, of a c64 modules/math.k's
    println(sin(PI / 2.0), " ", abs(exp(i * PI) + 1.0) < 1e-15)

    var r:c64
    var s:c64
    roots(c64(1.0), c64(2.0), c64(5.0), &r, &s)
    show(r); printf(" "); show(s); printf("\n")

    // the fifth roots of unity, and their sum
    var sum:c64 = c64(0.0)
    for k in 0..<5 {
        let w:c64 = polar(1.0, 2.0 * PI * float64(k) / 5.0)
        show(w); printf(k < 4 ? " " : "\n")
        sum += w
    }
    show(sum); printf("\n")

    // a discrete Fourier transform of 1, 2, 3, 4
    let x:[float64](4) = [1.0, 2.0, 3.0, 4.0]
    for k in 0..<4 {
        var X:c64 = c64(0.0)
        for n in 0..<4 {
            X += x[n] * exp(-2.0 * PI * i * float64(k * n) / 4.0)
        }
        show(X); printf(k < 3 ? " " : "\n")
    }
    return 0
}
// out: 1.0 true
// out: -1.0000+2.0000i -1.0000-2.0000i
// out: 1.0000+0.0000i 0.3090+0.9511i -0.8090+0.5878i -0.8090-0.5878i 0.3090-0.9511i
// out: 0.0000+0.0000i
// out: 10.0000+0.0000i -2.0000+2.0000i -2.0000+0.0000i -2.0000-2.0000i
