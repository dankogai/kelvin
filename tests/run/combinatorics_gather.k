// seed.gather(ix): the elements of a program's own seed at the indices a
// Combinatorics kind gives, an Array of any type or a String's graphemes,
// with no global seed for an anonymous function to read (#615, #617)
#import <Combinatorics>

let main():int32 {
    let seed = $["a", "b", "c", "d"]
    for ix in Combination(4, 2) { print(seed.gather(ix), " ") }
    println()
    let word = $"héllo"                            // é is one grapheme
    let p = Permutation(5)
    println(word.gather(p[0]), " ", word.gather(p[119]), " ", $"🇯🇵🇺🇸".gather($[1, 0]))
    for ix in UniquePermutation(&$[0, 0, 1]) { print($"xy".gather(ix), " ") }
    println()
    let names:$[cstr] = $["x", "y"]
    let bytes:$[u8] = $[65, 66]
    let small:$[i32] = $[7, 8, 9]
    let codes:$[u32] = $[0x41, 0x1F600]
    println(names.gather($[1, 0]), " ", $[true, false].gather($[1, 1]), " ", $[10, 20, 30].gather($[2, 0]), " ", $[1.5, 2.5].gather($[1]))
    println(bytes.gather($[1]), " ", small.gather($[2, 2]), " ", codes.gather($[1]), " ", seed.gather(Array<i64>()), " ", seed)
    let ix = Combination(4, 3)[3]
    println(seed.gather(ix), " ", ix)               // ix is looked at: still its own
    println(seed.gather(Permutation(4)[23]), " ", seed.gather(BaseN(2, 3)[6]))
    return 0
}
// out: ["a", "b"] ["a", "c"] ["a", "d"] ["b", "c"] ["b", "d"] ["c", "d"] 
// out: héllo olléh 🇺🇸🇯🇵
// out: xxy xyx yxx 
// out: ["y", "x"] [false, false] [30, 10] [2.5]
// out: [66] [9, 9] [128512] [] ["a", "b", "c", "d"]
// out: ["b", "c", "d"] [1, 2, 3]
// out: ["d", "c", "b", "a"] ["a", "b", "b"]
