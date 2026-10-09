// an Array of a struct that owns waits for its own change (#57)
struct m { b: Bytes }
let main():i32 {
    var xs = Array<m>()
    return 0
}
// error: an Array of struct m, a struct that owns, is not here yet: a Bytes, a String or an Array may be an element
