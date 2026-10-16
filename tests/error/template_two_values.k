// error: expected '}' to end ${...} in the template literal, found 'b'
let main():int32 {
    let a = 1
    let b = 2
    println(`${a b}`)
    return 0
}
