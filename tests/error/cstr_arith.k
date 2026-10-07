// a cstr is text, not a cursor (#52): no pointer arithmetic on it
let main():i32 {
    let s:cstr := "hello"
    let t:cstr := s + 2
    return 0
}
// error: a cstr is text, not a cursor (#52): walk it with 'for c in s', index it, or step a 'var p:u8^ := s'
