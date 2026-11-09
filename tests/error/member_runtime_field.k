// a built-in type's own C field is the runtime's, no member of Kelvin's,
// where it compiled; its spelling is named (#497)
let main():int32 {
    let b = Bytes("x")
    println(b.cap)
    return 0
}
// error: '.cap' is the runtime's C field of a Bytes, no member of Kelvin's: its spelling is '.capacity'
