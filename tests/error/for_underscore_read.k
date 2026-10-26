// `for _ in` names no loop variable (#388): kelvinc says so, not C
let main():int32 {
    for _ in 0..<3 {
        println(_)
    }
    return 0
}
// error: '_' names nothing to read: it leaves out a name, as of an unnamed parameter or of 'for _ in'
