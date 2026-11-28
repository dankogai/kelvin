// {} given to a Dictionary is no empty one (#787), as kelvinc says it,
// at its {: kc built it
let main():int32 {
    var d:${String: int64} = {}
    return 0
}
// error: an empty Dictionary is written ${:}
