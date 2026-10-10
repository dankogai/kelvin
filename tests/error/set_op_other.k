// | takes two Sets of the same elements, in variables (#73)
let main():i32 {
    var s = ${1, 2}
    var t = ${"a"}
    var u = s | t
    return 0
}
// error: '|' takes two Sets of the same elements, both in variables
