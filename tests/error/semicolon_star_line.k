// error: dereference is a postfix '^' in Kelvin: write 'p^' instead of '*p'
let main():int32 {
    var x:int32 = 0
    var p:int32^ := &x
    println(x)
    *p = 1
    return 0
}
