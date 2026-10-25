// an unsigned Range steps by its unsigned T, never down (#379)
let main():int32 {
    let b:Range<uint8> = 0...9
    for i in b.stride(-1) { }
    return 0
}
// error: a Range<u8> steps by a u8, which is never negative: walk it down with '.reversed()'
