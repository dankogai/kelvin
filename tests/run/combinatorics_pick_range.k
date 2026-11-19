// an index past the seed ends the program, as an Array's does (#615)
#import <Combinatorics>
let main():int32 {
    let seed = $[$"a", $"b"]
    println("before ", pick(&seed, $[1]))
    println(pick(&seed, $[2]))
    return 0
}
// out: before ["b"]
// exit: 1
// err: kelvin: index 2 is out of range: the Array has 2
