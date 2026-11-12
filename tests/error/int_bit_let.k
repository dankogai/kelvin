// x.bits[n].flip() changes x, so x is a var (#454, #530)
let main():int32 {
    let x:i32 = 0
    x.bits[1].flip()
    return 0
}
// error: '.flip' is a var method, which changes 'x', a let: declare it with var
