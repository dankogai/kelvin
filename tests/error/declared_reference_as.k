// := of a conversion written with as (#769), as of one written v:T
let main():int32 {
    var y:int32 = 5
    var x := y as int64
    return 0
}
// error: 'x' would be a value (i64): use '=' for a value, or annotate a reference such as 'i64^'
