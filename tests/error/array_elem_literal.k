// error: an element of Array<i64> is an i64, and this is text
let main():int32 {
    var xs:Array<int64> = $[1, "two"]
    return 0
}
