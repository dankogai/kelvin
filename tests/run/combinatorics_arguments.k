// a size below 0 is no Combinatorics object's, and a count of 0 has no
// sample (#614)
#import <Combinatorics>
let main():int32 {
    println(Combination(3, 5).count, " ", Combination(3, 5).map { $0.copy() }.count)
    println(Combination(3, 5).sample())
    return 0
}
// out: 0n 0
// exit: 1
// err: kelvin: sample() of no element: the count is 0
