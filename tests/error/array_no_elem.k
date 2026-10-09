// Array(n) has no element type to infer: Array<T>(n), or the elements (#58)
let main():i32 {
    var xs = Array(3)
    return 0
}
// error: Array(x) has no element type: write Array<T>(x), or the elements, Array([...])
