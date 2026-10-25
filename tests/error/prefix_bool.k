// .prefix { ... } keeps values while its function says true, a bool (#372)
let main():int32 {
    let xs = $[1, 2, 3]
    println(xs.prefix { $0 + 1 })
    return 0
}
// error: '.prefix' looks for what its function says true for, a bool, and this gives a number: compare it, as in 'x != 0'
