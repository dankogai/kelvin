// a variable of a number is no function to call (#620)
let main():int32 {
    let x = 2.0
    println(x(1.0))
    return 0
}
// error: 'x' is a variable of f64, not a function: what is called is a function or a variable of a function type
