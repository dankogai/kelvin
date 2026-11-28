// arithmetic added to an Array of pointers is a number (#787): kc left
// it to C, incompatible integer to pointer conversion
let main():int32 {
    var x:int64 = 1
    var a:$[int64^] = $[]
    a += x + 1
    return 0
}
// error: an element of Array<i64^> is an i64^, and this is a number
