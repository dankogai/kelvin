// an index past the count ends the program, as an Array's does (#614, #174)
#import <Combinatorics>
let main():int32 {
    let p = Permutation(3)
    println("before ", p[5])
    println(p[6])
    return 0
}
// out: before [2, 1, 0]
// exit: 1
// err: kelvin: index 6 is out of range: the Permutation has 6
