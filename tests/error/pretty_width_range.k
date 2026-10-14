// .pretty(n) indents 0 to 10 spaces a level (#127)
let main():i32 {
    var xs = $[1, 2]
    println(xs.pretty(11))
    return 0
}
// error: '.pretty(n)' indents 0 to 10 spaces a level, as JSON.stringify's space does, and this is 11
