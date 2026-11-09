// an operand lent to an operator is a let; a var parameter asks for a
// copy of its own, to change (#501)
struct bag { name: String; n: int64 }
let +(a:bag, b:bag):bag {
    a.n += b.n
    return a.copy()
}
let main():int32 {
    let x:bag = {$"x", 1}
    println(x + x)
    return 0
}
// error: 'a' is a let parameter and cannot change; write 'var a' in the parameter list
