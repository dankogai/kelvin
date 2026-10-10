// a Set has no text yet (#71)
let main():i32 {
    var s = ${1, 2}
    println(s)
    return 0
}
// error: a Set has no text yet: println its elements, as in 'for x in xs'
