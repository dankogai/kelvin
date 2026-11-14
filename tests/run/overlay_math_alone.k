// with <math> alone, modules/math+Rational.k is not read (#551, #552):
// cbr and complexBigRat are the program's own names, a struct and a
// function, and bigrat is no type
#import <math>
struct cbr { carbon: f64; boron: f64 }
let complexBigRat(x:f64):f64 { x * 2.0 }
let bigrat(x:f64):f64 { x + 1.0 }
let main():int32 {
    let c:cbr = {1.5, 2.5}
    println(c, " ", complexBigRat(c.carbon), " ", bigrat(c.boron), " ", abs(c64(3.0, 4.0)))
    return 0
}
// out: {carbon: 1.5, boron: 2.5} 3.0 3.5 5.0
