// a case with no value has nothing to bind (#78)
let main():int32 {
    var o:int64? = none
    if let none(x) = o { }
    return 0
}
// error: case 'none' of i64? carries no value to bind: test it with '.is(none)'
