// a negative index of xs.gather(ix) is out of range, and named as itself (#618)
let main():int32 {
    let seed = $["a", "b"]
    println("before ", seed.gather([1, 0]))
    println(seed.gather($[0, -1]))
    return 0
}
// out: before ["b", "a"]
// exit: 1
// err: kelvin: index -1 is out of range: the Array has 2
