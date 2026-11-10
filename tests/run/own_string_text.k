// a type's own text as a String, let T.string:String { ... } (#506): print,
// println, $`...`, .pretty and a value that holds it show it whole, however
// big; `...` and .cstr cut it at 256 bytes, as a String value's
#import <string.h> as C
struct digits { n: i64 }
let digits.string:String {
    var s = $""
    for i in 0..<.n { s += "9" }
    return s
}
struct pair { a: digits; k: i64 }
enum shade { none; grey: u8 }
extend shade {
    let string:String { .is(grey) ? $`grey ${.grey}` : $"no shade" }
}
let main():int32 {
    let big:digits = {1000}
    var t = $`${big}`
    let small:digits = {3}
    println(small, " ", t.count, " ", strlen(`${big}`), " ", strlen(big.cstr), " ", `<${small}>`)
    var xs:$[digits] = $[]
    xs.append(small)
    xs.append((digits){2})
    let p:pair = {small, 5}
    println(xs, " ", p, " ", shade.grey(7), " ", shade.none)
    println(p.pretty)
    var whole = $""
    whole += big.string
    println(whole.count)
    return 0
}
// out: 999 1000 256 256 <999>
// out: [999, 99] {a: 999, k: 5} grey 7 no shade
// out: {
// out:   a: 999,
// out:   k: 5
// out: }
// out: 1000
