// an empty Dictionary is written ${:}: ${} where a Dictionary's type is
// written is said at the value's start, the $ (#786), as kc says it,
// where kelvinc said it at the }
let main():int32 {
    var d:${String: int64} = ${}
    return 0
}
// error: an empty Dictionary is written ${:}
