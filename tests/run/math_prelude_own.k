// a program that defines a type of one of math's types' names, c64, has
// its own (#591), as one that defines a RegExp has its own (#504): conj
// and exp here are the program's own, and its c64 prints as the struct
// it is. It hides math's under the bare name, and no longer keeps math
// out (#600): tests/run/kelvin_types.k has the two side by side
struct c64 { re: i64; im: i64 }
let size(z:c64):i64 { z.re * z.re + z.im * z.im }
let conj(z:c64):c64 { (c64){z.re, 0 - z.im} }
let exp(n:i64):i64 { n * 2 }
let main():int32 {
    let z:c64 = {3, 4}
    println(size(z), " ", conj(z).im, " ", exp(21), " ", z.typename)
    println(z)
    return 0
}
// out: 25 -4 42 c64
// out: {re: 3, im: 4}
