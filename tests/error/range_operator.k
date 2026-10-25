// a Range has no operators (#373) but == and != (#376)
let main():int32 {
    let b = 0..<3 < 0..<4
    return 0
}
// error: a Range has no operator '<', but == and !=: walk it, or gather its values, as in '.map { $0 }'
