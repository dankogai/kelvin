// o -= 1 of a struct with no such operator is said at the operator
// (#769), where kc said it at the line's start
struct named { s:String, n:int64 }
let main():int32 {
    var o:named = {$"a", 1}
    o -= 1
    return 0
}
// error: no operator - takes named and i64: define one, as in 'let -(a:named, b:i64):... { ... }'
