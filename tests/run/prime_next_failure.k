// n.nextPrime of <Prime> ends the program where no greater prime fits n's
// type (#668): 127 is i8's greatest, and 131 does not fit
#import <Prime>
let main():int32 {
    let n:i8 = 113
    println(n.nextPrime)
    let m:i8 = 127
    println(m.nextPrime)
    return 0
}
// out: 127
// exit: 1
// err: kelvin: 127.nextPrime has no value: no prime above 127 fits i8
