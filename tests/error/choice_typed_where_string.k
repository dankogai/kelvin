// a choice of two variables of one type is of that type where another
// goes (#792), as kelvinc types it: kc left it to C
let main():int32 {
    var x:int64 = 1
    var y:int64 = 2
    var s:String = true ? x : y
    return 0
}
// error: 's' is a String, and this is i64
