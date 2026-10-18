// the result of a .map function (#182) is inferred from arithmetic only
// where its operands are of one number type: an i64 and an i32 are not,
// as C would promote them, so the result is written
let k:int32 = 3
let main():int32 {
    var xs = $[1, 2]
    var ys = xs.map { $0 * k }
    return 0
}
// error: the result of this function is not a type kelvinc sees
