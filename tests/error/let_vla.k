// [T](n) of a count C computes is a VLA, zero-filled after its
// declaration, which a let cannot be (#49)
let main(argc:int32, argv:[cstr]):int32 {
    let n = int64(argc)
    let a = [uint8](n)
    return 0
}
// error: 'a' is a let of a count computed at run time, which C cannot fill: write 'var a'
