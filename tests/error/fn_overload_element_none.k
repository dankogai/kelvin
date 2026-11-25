// an overloaded name where functions of another type are the elements
// (#764): none of its overloads is of the type
let twice(x:int64):int64 { x * 2 }
let twice(x:float64):float64 { x * 2.0 }
let main():int32 {
    var a:$[(String):int64] = $[]
    a += twice
    return 0
}
// error: no function 'twice' is (String):i64
