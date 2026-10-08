// print of an owner an expression gives would never free it (#54, #55)
let main():i32 {
    var s = String("x")
    println(s.copy())
    return 0
}
// error: println of an owner that an expression gives, which nothing would free: bind it to a variable first
