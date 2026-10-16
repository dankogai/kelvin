// error: an anonymous function cannot use 'n' of the function around it
let each(k:int64, f:(int64)) { f(k) }
let main():int32 {
    let n:int64 = 5
    each(1) { println(`${$0 + n}`) }
    return 0
}
