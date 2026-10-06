// [T](n) of a count C computes is a VLA, zero-filled after its
// declaration, which a let cannot be (#49)
let main(argc:i32, argv:[cstr]):i32 {
    let n = i64(argc)
    let a = [u8](n)
    return 0
}
// error: 'a' is a let of a count computed at run time, which C cannot fill: write 'var a'
