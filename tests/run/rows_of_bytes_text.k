// rows of bytes of a count take text (#769), C's array of it, which kc
// refused
let main():int32 {
    var m:[[uint8](3)](2) = ["ab", "cd"]
    println(m[0][0], " ", m[1][1], " ", m[1][2], " ", m.count, " ", m[0].count)
    return 0
}
// out: 97 100 0 2 3
