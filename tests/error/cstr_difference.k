// two cstrs have no difference (#52, #282): x - y was of two unrelated
// addresses
let main():int32 {
    let x:cstr := "a"
    let y:cstr := "b"
    println(x - y)
    return 0
}
// error: a cstr is text, not a cursor (#52): walk it with 'for c in s', index it, or step a 'var p:u8^ := s'
