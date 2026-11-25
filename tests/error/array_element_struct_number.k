// a number where an element that is a struct goes (#752): C went on
// inside the struct with it, its brace elision, and built the program
struct point { x:int64, y:int64 }
let main():int32 {
    var a:[point](1) = [5]
    println(a[0].x)
    return 0
}
// error: an element of [point](1) is a point, and this is a number
