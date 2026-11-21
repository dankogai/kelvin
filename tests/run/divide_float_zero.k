// what #662 leaves as it was: a float divided by zero is IEEE 754's
// infinity, of literals and of a variable, and an integer by what is not 0
let main():int32 {
    let inf = 1.0 / 0.0
    var f:f64 = -2.0
    var n:i64 = 7
    println(inf, " ", f / 0, " ", inf == f64.infinity, " ", n / 7, " ", n % 4)
    return 0
}
// out: inf -inf true 1 3
