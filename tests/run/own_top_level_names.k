// A name of the program's own top level that is no function hides the
// prelude's of that name (#604), and Kelvin.name is the prelude's: a
// variable named as one of its functions, let exp = 2.5, which C refused,
// "redefinition of 'exp' as different kind of symbol", as its math.h
// declares exp in every program; a word of an enum of the program's own;
// and anything named as a word of the prelude's enum, nfc, a function
// too. A member of such a name is a member still, read after a dot
let exp = 2.5
var floor:i64 = 3
enum Tag { nfd, rfid, log }
let nfc(x:i64):i64 { x * 2 }
struct P { abs: i64; exp: f64 }
extend P {
    let log:i64 { self.abs + 1 }
}
let abs = 7
let main():int32 {
    floor += 1
    let p:P = {3, 1.5}
    let t:Tag = nfd
    let s = $"é"
    println(exp, " ", floor, " ", abs, " ", nfc(3), " ", t as i64, " ", log as i64)
    println(p.abs, " ", p.exp, " ", p.log)
    println(Kelvin.exp(0.0), " ", Kelvin.floor(exp), " ", Kelvin.abs(-2), " ", Kelvin.log(1.0), " ", sqrt(4.0))
    println(Kelvin.nfc as i64, " ", Kelvin.nfd as i64, " ", s.normalize(Kelvin.nfd).codepoints.count)
    return 0
}
// out: 2.5 4 7 6 0 2
// out: 3 1.5 4
// out: 1.0 2.0 2 0.0 2.0
// out: 0 1 2
