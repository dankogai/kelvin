// error: '.hex' text lives in a buffer of this function, which is gone once it returns
let where(p:i32^):cstr { p.hex }
let main():i32 {
    var x:int32 = 1
    println(where(&x))
    return 0
}
