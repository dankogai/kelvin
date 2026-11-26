// Array(b) of an array of arrays is refused at b (#780), where
// kelvinc said it at b's declared type
let main():int32 {
    var b:[[int64](2)](1) = [[1, 2]]

    var a = Array(b)
    return 0
}
// error: an Array of [i64](2) is not here yet: an element is a value C returns
