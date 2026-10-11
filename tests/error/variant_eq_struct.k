// == of a Result compares the values, which a struct cannot (#79)
struct point { x: i32; y: i32 }
let main():i32 {
    var a:Result<point, i32> = {1, 2}
    var b:Result<point, i32> = {1, 2}
    println(a == b)
    return 0
}
// error: '==' of Result<point, i32> compares the values, and case 'ok' holds point, which has no '=='
