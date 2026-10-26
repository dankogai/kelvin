// !! takes 0 or 1, a literal checked (#387)
let main():int32 {
    println(!!2)
    return 0
}
// error: '!!' takes an integer 0 or 1, and this is 2
