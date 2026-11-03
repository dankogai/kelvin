// x.flip(n) changes x, so x is a var (#454)
let main():int32 {
    let x:i32 = 0
    x.flip(1)
    return 0
}
// error: '.flip' is a var method, which changes 'x', a let: declare it with var
