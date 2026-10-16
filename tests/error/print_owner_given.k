// print shows an owner it can free: one an expression gives is bound first (#123)
let make():$[int64] { $[1, 2] }
let main():i32 {
    println(make())
    return 0
}
// error: that an expression gives, which nothing would free, is not printed: bind it to a variable first
