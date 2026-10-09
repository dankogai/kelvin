// $[] has no element type to infer, as Array([]) has none (#62)
let main():i32 {
    var xs = $[]
    return 0
}
// error: Array([]) has no element type: write Array<T>()
