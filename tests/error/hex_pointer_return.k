// error: '.hex' text lives in a buffer of this function, which is gone once it returns
let where(p:int32^):cstr { p.hex }
let main():int32 {
    var x:int32 = 1
    println(where(&x))
    return 0
}
