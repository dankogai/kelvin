// map's anonymous function needs a result kelvinc sees (#80)
let main():i32 {
    var a:int64? = 3
    var m = a.map { $0 * 2 }
    return 0
}
// error: the result of this function is not a type kelvinc sees: write its parameters and result, as in '{ (v:i64):i64 in v * 2 }', or convert the value, as in 'i64(...)'
