// a Bytes grows by doubling, holds any count, and takes a template's text
// and a byte (#54)
let main():i32 {
    var b = Bytes()
    for i in 0..<100000 { b += "0123456789" }
    println(b.count, " ", b.capacity, " ", b[999999])
    var s = Bytes()
    s += `${b.count}`
    s += 7:u8
    println(s.count, " ", s[0], " ", s[s.count - 1])
    var big = Bytes(1000000)
    println(big.count)
    return 0
}
// out: 1000000 1048576 57
// out: 8 49 7
// out: 1000000
