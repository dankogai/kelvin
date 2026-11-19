// an [i64] parameter is a pointer in C, with no count to gather by (#618)
let first(a:[i64]):i64 { return $["x", "y"].gather(a).count }
let main():int32 {
    var z = [0]
    println(first(z))
    return 0
}
// error: '.gather' takes the indices as a $[i64] or an [i64](N), and this is i64^, a pointer: an array passed to a function is one, with no count
