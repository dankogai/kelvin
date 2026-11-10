// a parameter written b:lent T is lent its caller's owner (#510), as an
// operator's operands are (#501): the caller keeps it, one an expression
// gives is held and freed after the call; in a function and a method
struct bag { name: String; n: int64 }
let total(a:lent bag, b:lent bag):int64 { a.n + b.n + a.name.count as int64 }
let label(s:lent String, k:i64):String {
    var r = s.copy()
    r += $`#${k}`
    return r
}
extend bag {
    let merged(other:lent bag):bag { (bag){self.name + other.name, self.n + other.n} }
}
let mk(n:i64):bag { (bag){$"m", n} }
let main():int32 {
    let a:bag = {$"a", 1}
    let b:bag = {$"bb", 2}
    println(total(a, b), " ", total(a, a), " ", total(mk(5), b), " ", a, " ", b)
    let s = $"tag"
    println(label(s, 1), " ", label(s, 2), " ", s, " ", label($"x" + "y", 3))
    println(a.merged(b), " ", a.merged(a), " ", a.merged(mk(7)), " ", a, " ", b)
    return 0
}
// out: 4 3 8 {name: "a", n: 1} {name: "bb", n: 2}
// out: tag#1 tag#2 tag xy#3
// out: {name: "abb", n: 3} {name: "aa", n: 2} {name: "am", n: 8} {name: "a", n: 1} {name: "bb", n: 2}
