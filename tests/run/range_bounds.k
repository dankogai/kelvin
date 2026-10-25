// r.lowerBound and r.upperBound (#375): its bounds as written, of T, as
// Swift's; ..<hi's lower one is 0, and lo... has no upper one
let ends(lo:int64):Range { return lo... }
let main():int32 {
    let r = 0..<5
    let b:Range<uint8> = 250...255
    let m = -3..<3
    println(r.lowerBound, " ", r.upperBound, " ", (1...3).upperBound, " ", b.lowerBound, " ", b.upperBound.typename, " ",
            m.lowerBound, " ", (..<4).lowerBound, " ", (0...).lowerBound)
    let w:int64 = r.upperBound - r.lowerBound
    println(w, " ", ends(7).lowerBound)
    println(ends(7).upperBound)
    return 0
}
// out: 0 5 3 250 u8 -3 0 0
// out: 5 7
// exit: 1
// err: kelvin: this Range has no end, and '.upperBound' is its end: its values go up to its type's largest
