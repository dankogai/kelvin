// braces are an initializer's: an argument where a T? goes writes its type (#32, #725)
let pick(o:int64?):int64 { o ?? -1 }
let main():int32 {
    println(pick({}))
    return 0
}
// error: a list is not a value here: the parameter is i64?, so write a compound literal, as in '(i64?){...}'
