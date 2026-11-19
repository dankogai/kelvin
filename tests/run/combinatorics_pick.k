// pick(&seed, ix): the elements of a program's own seed at the indices a
// Combinatorics kind gives, an Array of one of eight types or a String's
// graphemes, with no global seed for an anonymous function to read (#615)
#import <Combinatorics>

let main():int32 {
    let seed = $[$"a", $"b", $"c", $"d"]
    for ix in Combination(4, 2) { print(pick(&seed, ix), " ") }
    println()
    let word = $"héllo"                            // é is one grapheme
    let p = Permutation(5)
    println(pick(&word, p[0]), " ", pick(&word, p[119]), " ", pick(&$"🇯🇵🇺🇸", $[1, 0]))
    for ix in UniquePermutation(&$[0, 0, 1]) { print(pick(&$"xy", ix), " ") }
    println()
    let names:$[cstr] = $["x", "y"]
    let bytes:$[u8] = $[65, 66]
    let small:$[i32] = $[7, 8, 9]
    let codes:$[u32] = $[0x41, 0x1F600]
    println(pick(&names, $[1, 0]), " ", pick(&$[true, false], $[1, 1]), " ", pick(&$[10, 20, 30], $[2, 0]), " ", pick(&$[1.5, 2.5], $[1]))
    println(pick(&bytes, $[1]), " ", pick(&small, $[2, 2]), " ", pick(&codes, $[1]), " ", pick(&seed, Array<i64>()), " ", seed)
    let ix = Combination(4, 3)[3]
    println(pick(&seed, ix), " ", ix)               // ix is lent: still its own
    return 0
}
// out: ["a", "b"] ["a", "c"] ["a", "d"] ["b", "c"] ["b", "d"] ["c", "d"] 
// out: héllo olléh 🇺🇸🇯🇵
// out: xxy xyx yxx 
// out: ["y", "x"] [false, false] [30, 10] [2.5]
// out: [66] [9, 9] [128512] [] ["a", "b", "c", "d"]
// out: ["b", "c", "d"] [1, 2, 3]
