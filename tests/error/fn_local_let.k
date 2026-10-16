// a function is declared at the top level; inside one, a let holds an
// anonymous function (#32, #45)
let main():int32 {
    let twice(n:int64):int64 { n * 2 }
    return int32(twice(0))
}
// error: a function is declared at the top level; here a let holds an anonymous one, as in 'let twice:(T):R := { (a:T):R in ... }' (#32, #45)
