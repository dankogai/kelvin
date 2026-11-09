// an operator is lent an owner operand, its caller's, which it cannot
// return: a copy goes out (#501)
struct bag { name: String; n: int64 }
let +(a:bag, b:bag):bag { return a }
let main():int32 {
    let x:bag = {$"x", 1}
    println(x + x)
    return 0
}
// error: 'a' is an operand its caller keeps, lent to the operator: return a copy, 'a.copy()'
