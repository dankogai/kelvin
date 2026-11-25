// a := $[] of an Array is := of a value (#755, #764), said before the
// empty Array is asked its element type
let main():int32 {
    var a:$[int64] = $[1]
    a := $[]
    return 0
}
// error: 'a' is a value (Array<i64>): assign it with '=', not ':='
