// A type of the program's own with the name of one of the prelude's
// (#600) hides it under the bare name, and Kelvin.T is the prelude's:
// the two are two types. It kept the prelude's out before, BigInt and
// RegExp (#504, #508), and an own c64 all of math (#591); a literal,
// 123n or $/.../, was an error beside it, and is the prelude's. So are
// the words of the prelude's enum, Kelvin.nfd, where the program has a
// NormalForm and an nfd of its own. Each prints its own name
struct BigInt { digits: cstr }
struct c64 { re: i64; im: i64 }
struct RegExp { plain: bool }
struct Match { at: i64 }
enum NormalForm { raw, cooked }
extend BigInt {
    let count:i64 { strlen(self.digits) as i64 }
}
let BigInt(n:i64):BigInt { n < 0 ? (BigInt){"-"} : (BigInt){"+"} }
let abs(z:c64):i64 { z.re + z.im }
let main():int32 {
    let b:BigInt = {"123"}
    let big:Kelvin.BigInt = 2n ** 70 + Kelvin.BigInt(1)
    var bigs:$[Kelvin.BigInt] = $[]
    bigs += 5n
    println(b, " ", b.count, " ", BigInt(-1), " ", big, " ", bigs, " ", b.typename, " ", big.typename)
    let z:c64 = {3, 4}
    let w = Kelvin.c64(3.0, 4.0)
    println(abs(z), " ", abs(w), " ", z, " ", w, " ", sqrt(4.0), " ", z.typename, " ", w.typename)
    let r:RegExp = {true}
    let m:Match = {5}
    let s = $"caat"
    println(r, " ", m, " ", $/a+/.test(&s), " ", Kelvin.RegExp("a+", "").test(&s))
    let n:NormalForm = cooked
    let nfd = 7
    let e = $"é"
    println(n as i64, " ", n.typename, " ", nfd, " ", Kelvin.nfkd as i64, " ", e.normalize(Kelvin.nfd).codepoints.count)
    return 0
}
// out: {digits: "123"} 3 {digits: "-"} 1180591620717411303425n [5n] BigInt BigInt
// out: 7 5.0 {re: 3, im: 4} (3.0+4.0.i) 2.0 c64 c64
// out: {plain: true} {at: 5} true true
// out: 1 NormalForm 7 3 2
