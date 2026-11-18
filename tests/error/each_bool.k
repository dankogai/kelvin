// for x in s walks what has elements, and a bool has none, nor has an IO
// or a function: kc ended itself here, of a number too (#610)
let main():int32 {
    let b = true
    for x in b {
    }
    return 0
}
// error: for x in s walks a pointer, a list or an array, and this is bool; for a count, write 'for i in 0..<n'
