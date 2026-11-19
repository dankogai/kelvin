// an index past the seed ends the program, as an Array's does (#615, #617)
#import <Combinatorics>
let main():int32 {
    let seed = $["a", "b"]
    println("before ", seed.gather(Combination(2, 1)[1]))
    println(seed.gather(CartesianProduct(3, 1)[2]))
    return 0
}
// out: before ["b"]
// exit: 1
// err: kelvin: index 2 is out of range: the Array has 2
