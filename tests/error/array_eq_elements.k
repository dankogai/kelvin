// error: compares the elements, and pt has no '=='
struct pt { x: int64 }

let main():int32 {
    var a:Array<pt> = $[]
    var b:Array<pt> = $[]
    println(a != b)
    return 0
}
