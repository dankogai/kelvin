// A module's header names the prelude's types and writes no import of
// them: geo.kh's turned(z:c64) counts on math's being read before it. A
// module imported after it whose header writes #import <math>, as
// <BigNum>'s does, put math after geo.kh, and C did not know its c64,
// "unknown type name 'c64'". A module of the prelude that an import
// writes is read first, where the prelude's is (#601)
#import <geo>
#import <BigNum>
let main():int32 {
    println(turned(c64(1.0, 2.0)), " ", sqrt(BigFloat(4)), " ", abs(CBF(turned(c64(3.0, 4.0)))))
    return 0
}
// out: (-2.0+1.0.i) 2.0 5.0
