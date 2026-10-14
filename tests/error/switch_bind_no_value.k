// case none(x): binds nothing: the case carries no value (#119)
let main():i32 {
    var a:i64? = 3
    switch a {
    case some(v): println(v)
    case none(x): println("none")
    }
    return 0
}
// error: case 'none' of i64? carries no value: nothing to bind, write 'case none:'
