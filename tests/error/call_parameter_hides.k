// a parameter named as a function of the program hides it too (#620)
let sq(x:f64):f64 { return x * x }
let twice(sq:i64):f64 { return sq(2.0) * 2.0 }
let main():int32 {
    println(twice(1))
    return 0
}
// error: 'sq' is a variable here, of i64, which hides the function of its name: rename one of them
