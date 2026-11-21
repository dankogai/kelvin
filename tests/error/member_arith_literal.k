// error: u32 has no member 'bar'
// a literal in arithmetic is C's type there (#669): 0xffffffff is C's
// unsigned int, and n + 0xffffffff of an i32 an unsigned int, a u32
let main():int32 {
    let n:i32 = 1
    println((n + 0xffffffff).bar)
    return 0
}
