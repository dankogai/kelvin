// == of a Result compares the values, which a struct cannot (#79)
struct point { x: int32; y: int32 }
let main():int32 {
    var a:Result<point, int32> = {1, 2}
    var b:Result<point, int32> = {1, 2}
    println(a == b)
    return 0
}
// error: '==' of Result<point, i32> compares the values, and case 'ok' holds point, which has no '=='
