// a local named as a function hides it, and calling it is kelvinc's error,
// not C's "called object type 'double' is not a function" (#620)
let main():int32 {
    let sqrt = 2.0
    println(sqrt(sqrt))
    return 0
}
// error: 'sqrt' is a variable here, of f64, which hides the function of its name: rename one of them
