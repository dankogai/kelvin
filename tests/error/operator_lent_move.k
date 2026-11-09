// an operand lent to an operator moves into no function, as its caller
// keeps it (#501)
struct bag { name: String; n: int64 }
let keep(x:bag):int64 { x.n }
let +(a:bag, b:bag):bag {
    let n = keep(a)
    return (bag){b.name.copy(), n + b.n}
}
let main():int32 {
    let x:bag = {$"x", 1}
    println(x + x)
    return 0
}
// error: 'a' is an operand its caller keeps, lent to the operator: pass a borrow, '&a', or a copy
