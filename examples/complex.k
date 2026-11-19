// Complex numbers, the prelude's: c64 (complex64 by its alias), functions
// of one name for several types, with C's own for the numbers, operators
// a struct defines, and f64.pi; no import. A number to four decimals is a
// String a template makes.

// x to four decimals, rounded, with a + before one that is not negative
// where plus is true; what rounding leaves around 0 is 0
let fixed(x:f64, plus:bool):String {
    let n = (x.abs * 10000.0 + 0.5) as i64
    let digits = String(n % 10000 + 10000)                // 1dddd: the four, with their zeros
    let sign:cstr := x < 0.0 && n > 0 ? "-" : plus ? "+" : ""
    return $`${sign}${n / 10000}.${digits[1...]}`
}

let show(z:c64):String { $`${fixed(z.real, false)}${fixed(z.imag, true)}i` }

// the roots of a z² + b z + c
let roots(a:c64, b:c64, c:c64, r:c64^, s:c64^):() {
    let d:c64 = sqrt(b * b - 4.0 * a * c)
    r^ = (-b + d) / (2.0 * a)
    s^ = (-b - d) / (2.0 * a)
}

let main():i32 {
    let i:c64 = c64(0.0, 1.0)

    // sin of a number is C's, of a c64 the prelude's
    println(sin(f64.pi / 2.0), " ", abs(exp(i * f64.pi) + 1.0) < 1e-15)

    var r:c64
    var s:c64
    roots(c64(1.0), c64(2.0), c64(5.0), &r, &s)
    println(show(r), " ", show(s))

    // the fifth roots of unity, and their sum
    var sum:c64 = c64(0.0)
    for k in 0..<5 {
        let w:c64 = polar(1.0, 2.0 * f64.pi * f64(k) / 5.0)
        print(show(w), k < 4 ? " " : "\n")
        sum += w
    }
    println(show(sum))

    // a discrete Fourier transform of 1, 2, 3, 4
    let x:[f64](4) = [1.0, 2.0, 3.0, 4.0]
    for k in 0..<4 {
        var X:c64 = c64(0.0)
        for n in 0..<4 {
            X += x[n] * exp(-2.0 * f64.pi * i * f64(k * n) / 4.0)
        }
        print(show(X), k < 3 ? " " : "\n")
    }
    return 0
}
// out: 1.0 true
// out: -1.0000+2.0000i -1.0000-2.0000i
// out: 1.0000+0.0000i 0.3090+0.9511i -0.8090+0.5878i -0.8090-0.5878i 0.3090-0.9511i
// out: 0.0000+0.0000i
// out: 10.0000+0.0000i -2.0000+2.0000i -2.0000+0.0000i -2.0000-2.0000i
