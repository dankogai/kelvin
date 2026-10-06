// inside a function, a var does not declare a function either (#32, #45)
let main():i32 {
    var twice(n:i64):i64 { n * 2 }
    return i32(twice(0))
}
// error: a function is declared at the top level; here a let holds an anonymous one, as in 'let twice:(T):R := { (a:T):R in ... }' (#32, #45)
