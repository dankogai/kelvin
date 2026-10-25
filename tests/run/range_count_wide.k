// a Range of 2^64 values has more than a u64 count holds (#374): its
// count ends the program, as a check does
let main():int32 {
    let all:Range<uint64> = 0...18446744073709551615
    println(all.contains(18446744073709551615))
    println(all.count)
    return 0
}
// out: true
// exit: 1
// err: kelvin: this Range has 2^64 values, more than a count holds
