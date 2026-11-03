// b.flip() of a bool takes nothing (#454)
let main():int32 {
    var b = true
    b.flip(1)
    return 0
}
// error: '.flip()' of a bool takes nothing: it is b = !b
