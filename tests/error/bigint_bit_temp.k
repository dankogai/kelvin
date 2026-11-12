// setting a bit changes its BigInt (#531), so one an expression gives has none to set
let main():int32 {
    var b = 5n
    (b + 1n).bits[0] = true
    return 0
}
// error: setting a bit of a BigInt changes it, so that BigInt is a variable
