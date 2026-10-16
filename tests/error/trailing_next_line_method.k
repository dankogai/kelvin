// error: a trailing function starts on the line of the call's ')': on the next line, '{' starts a block
struct box { n:int64 }
let box.each(f:(int64)) { f(.n) }
let main():int32 {
    let b:box = {1}
    b.each()
    {
        println("x")
    }
    return 0
}
