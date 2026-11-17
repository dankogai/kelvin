// <BigFloat> is <BigNum> now (#590), which has BigFloat, CBF, CBR and math's functions of them
#import <BigFloat>
let main():int32 {
    println(BigFloat(1) / 3)
    return 0
}
// error: <BigFloat> is <BigNum> now, with CBR, CBF and math's functions of them (#590): write #import <BigNum>
