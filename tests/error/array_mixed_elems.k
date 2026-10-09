// the elements of Array([...]) must have one type kelvinc sees (#58)
let main():i32 {
    var xs = Array(["a", 1])
    return 0
}
// error: the elements have no one type kelvinc sees here: write Array<T>([...])
