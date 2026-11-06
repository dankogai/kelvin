// operators of a struct that owns (#42, #471): an operand moves in, as
// into a function, and x op= y and x = x op y give x anew; a copy keeps
// what it is made of, and a struct that owns nothing is only read
struct bag { name: String; n: int64 }
let +(a:bag, b:bag):bag {
    var c = a.name.copy()
    c += &b.name
    return {.name = c.copy(), .n = a.n + b.n}
}
let ==(a:bag, b:bag):bool { a.n == b.n }
let -(a:bag):bag { (bag){a.name.copy(), -a.n} }
struct money { cents: int64 }
let ==(a:money, b:money):bool { a.cents == b.cents }
let main():int32 {
    var a:bag = {$"a", 1}
    var b:bag = {$"b", 2}
    println(a.copy() == b.copy(), " ", -a.copy(), " ", a, " ", b)
    var c = a.copy() + b.copy()
    println(c)
    c += b.copy()
    println(c)
    c = c + a.copy()
    println(c)
    let d = a + b                                        // a and b are moved out here
    a = d.copy()                                         // and a is given anew
    println(a, " ", d)
    let m:money = {1}
    let n:money = {1}
    println(m == n, " ", m == n, " ", m)
    return 0
}
// out: false {name: "a", n: -1} {name: "a", n: 1} {name: "b", n: 2}
// out: {name: "ab", n: 3}
// out: {name: "abb", n: 5}
// out: {name: "abba", n: 6}
// out: {name: "ab", n: 3} {name: "ab", n: 3}
// out: true true {cents: 1}
