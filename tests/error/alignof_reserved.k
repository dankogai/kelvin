// alignof is a reserved word (#395)
let main():i32 {
    var alignof = 3
    return 0
}
// error: expected a name, found 'alignof'
