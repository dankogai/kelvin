// error: an owner is not copied by '=' (#54)
let main():int32 {
    var s = $"a"
    var t = $"b"
    var c = true
    var u = c ? s : t
    return 0
}
