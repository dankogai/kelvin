// ok({}) is a list where a value goes, as ok({1, 2}) is (#736, #743):
// braces are an initializer's, 'var r:Result<point, i64> = {}'
struct point { x: int64; y: int64 }
let main():int32 {
    var r:Result<point, int64> = ok({})
    return 0
}
// error: a list is not a value here: write a compound literal, as in '(i32[3]){1, 2, 3}'; as a function with no parameters and no result, this would do nothing
