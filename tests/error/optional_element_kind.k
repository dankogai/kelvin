// an element where an Optional goes is said by its case (#757), as
// kelvinc says it, where kc said an element of [i64?](1) is an i64?
let main():int32 {
    var xs:[int64?](1) = ["a"]
    return 0
}
// error: case 'some' of i64? holds an i64, and this is text
