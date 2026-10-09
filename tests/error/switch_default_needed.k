// a switch handles every value (#63)
let main():i32 {
    var n:i32 = 1
    switch n {
    case 1:
        println(1)
    }
    return 0
}
// error: a switch handles every value: add 'default:'
