// a name past ASCII is Kelvin's, declared before it is used (#385)
let main():int32 {
    println(後(1))
    return 0
}
let 後(n:int64):int64 { n + 1 }
// error: '後' is not known: declare it before it is used
