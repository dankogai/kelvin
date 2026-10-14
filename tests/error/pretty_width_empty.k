// .pretty() with nothing between the parentheses: write .pretty (#127)
let main():i32 {
    var xs = $[1, 2]
    println(xs.pretty())
    return 0
}
// error: '.pretty(n)' takes the spaces a level, an integer from 0 to 10; two is '.pretty'
