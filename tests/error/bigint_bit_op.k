// a bit of a BigInt has =, |=, &= and ~= (#531), and no arithmetic
let main():int32 {
    var b = 5n
    b.bits[1] += true
    return 0
}
// error: a bit of a BigInt is set with '=', '|=', '&=' or '~=', and a bool, and has no '+='
