// var a = b of an array, no type written: an array read is its first
// element's address, a reference, which = does not give (#767), where
// kc said an array is not copied
let main():int32 {
    var b:[int64](2) = [3, 4]
    var a = b
    return 0
}
// error: 'a' is a reference (i64^): assign it with ':=', not '='
