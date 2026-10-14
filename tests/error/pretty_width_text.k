// .pretty(n) takes a number of spaces, not text (#127)
let main():i32 {
    var xs = $[1, 2]
    println(xs.pretty("  "))
    return 0
}
// error: '.pretty(n)' takes the spaces a level, an integer from 0 to 10, and this is text
