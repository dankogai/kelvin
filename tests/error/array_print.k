// an Array has no text yet (#57)
let main():i32 {
    var xs = Array<i64>()
    println(xs)
    return 0
}
// error: an Array has no text yet: println its elements, as in 'for x in xs'
