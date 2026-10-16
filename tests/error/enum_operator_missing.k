// an enum with values has == and != of its own, and other operators only as the program defines them (#121)
enum maybe { none; some: int64 }
let main():int32 {
    var a = maybe.some(1)
    var b = maybe.some(2)
    var c = a + b
    return 0
}
// error: has no operator '+': compare with == and !=, or define one, as in 'let +(a:T, b:T):T { ... }' (#121)
