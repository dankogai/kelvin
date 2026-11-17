// <Rational> and <BigNum> are libraries (#599), libkRational.a and
// libkBigNum.a, and BigNum's uses Rational's: it is linked before it
// whatever the order of the two imports, as C's linker reads each library
// once. Here Rational is imported first and nothing of it is named, so
// that only BigNum's library asks for it
#import <Rational>
#import <BigNum>
let main():int32 {
    println(sqrt(BigFloat(2)), " ", exp(BigFloat(1)), " ", BigFloat.precision)
    return 0
}
// out: 1.41421356237309504880168872420969807857 2.71828182845904523536028747135266249776 128
