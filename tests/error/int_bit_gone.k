// x.bit(n) of an integer, #454's, is x.bits[n] (#530)
let main():int32 {
    var x:u8 = 5
    println(x.bit(2))
    return 0
}
// error: '.bit(n)' is no more (#530): an integer's bit is 'x.bits[n]', a bool, set with '=', '|=', '&=' and '~='
