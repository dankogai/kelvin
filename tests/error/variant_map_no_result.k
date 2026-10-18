// map's anonymous function needs a result kelvinc sees (#80): arithmetic
// gives one where its operands agree (#182), and an int64 times a floating
// literal is not one, which C would make a double
let main():int32 {
    var a:int64? = 3
    var m = a.map { $0 * 2.5 }
    return 0
}
// error: the result of this function is not a type kelvinc sees: write its parameters and result, as in '{ (v:i64):i64 in v * 2 }', or convert the value, as in 'i64(...)'
