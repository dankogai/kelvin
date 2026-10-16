// a struct takes a value of its own type, said the Kelvin way (#59)
struct point { x: int32 }
struct size { x: int32 }
let main():int32 {
    var p:point = {1}
    var s:size = {2}
    s = p
    return 0
}
// error: point is not size: a struct takes a value of its own type
