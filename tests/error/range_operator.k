// a Range has no operators (#373), == among them
let main():int32 {
    let b = 0..<3 == 0..<3
    return 0
}
// error: a Range has no operator '==': walk it, or gather its values, as in '.map { $0 }'
