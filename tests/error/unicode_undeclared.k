// a name past ASCII is Kelvin's (#385): one declared nowhere is not known,
// called before it is written or not (#505)
let main():int32 {
    println(後(1))
    return 0
}
// error: '後' is not known: declare it before it is used
