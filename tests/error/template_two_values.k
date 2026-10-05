// error: expected '}' to end ${...} in the template literal, found 'b'
main():i32 {
    let a = 1
    let b = 2
    println(`${a b}`)
    return 0
}
