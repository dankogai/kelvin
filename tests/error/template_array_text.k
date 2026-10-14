// a template's room is bounded, so an Array goes through print or .pretty (#123, #124)
let main():i32 {
    var xs = $[1, 2]
    let t := `xs = ${xs}`
    return 0
}
// error: an Array has no text in a template, whose room is bounded: print it with print or println, or bind its .pretty, a String, and show that (#123, #124)
