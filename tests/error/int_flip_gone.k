// x.flip(n) of an integer, #454's, is x.bits[n].flip() (#530)
let main():int32 {
    var x:u8 = 5
    x.flip(2)
    return 0
}
// error: '.flip(n)' of an integer is no more (#530): 'x.bits[n].flip()' flips its bit n
