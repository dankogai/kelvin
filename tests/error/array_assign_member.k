// a struct's array member is not set whole either (#648)
struct s { a:[i64](2) }
let main():int32 {
    var x:s = {[1, 2]}
    x.a = [3, 4]
    println(x.a[0])
    return 0
}
// error: an array is not assigned: assign its elements, a[i]
