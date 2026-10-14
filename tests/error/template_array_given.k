// an Array that an expression gives is bound before a template shows it (#125)
let make():$[i64] { $[1, 2] }
let main():i32 {
    let t := `xs = ${make()}`
    return 0
}
// error: an Array that an expression gives in a template, which nothing would free: bind it to a variable first
