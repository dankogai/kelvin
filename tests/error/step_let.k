// a let pointer does not move (#27, #51)
let main():i32 {
    let p:cstr := "hi"
    p++
    return 0
}
// error: 'p' is a let and cannot change; declare it with var
