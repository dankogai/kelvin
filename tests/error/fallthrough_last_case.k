// the last case of a switch has no next case to go on into (#386)
let main():int32 {
    var n = 1
    switch n {
    case 1: println(1)
    default:
        if n > 1 { fallthrough }
    }
    return 0
}
// error: 'fallthrough' in the last case of a switch, which has no next case to go on into
