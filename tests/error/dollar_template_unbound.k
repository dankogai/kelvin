// a String an expression gives in a $`...` would never be freed (#67)
let main():i32 {
    var s = $`${$"x"} and more`
    return 0
}
// error: a String that an expression gives in a template, which nothing would free: bind it to a variable first
