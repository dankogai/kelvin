// error: which is gone once it returns: the caller takes the text itself, as in 'println(x.hex)'
let hx(x:int64):cstr { x.hex }
let main():int32 {
    println(hx(255))
    return 0
}
