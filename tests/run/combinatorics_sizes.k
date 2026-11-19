// a size of Permutations and Combinations is from 0 to n, as Swift's
// (of:sizes:) has it (#615)
#import <Combinatorics>
let main():int32 {
    println("before ", Combinations(3, &$[0, 3]).count)
    println(Combinations(3, &$[2, 4]).count)
    return 0
}
// out: before 2n
// exit: 1
// err: kelvin: the sizes of Permutations and Combinations are from 0 to n
