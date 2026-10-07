// a cstr is text, not a cursor (#52): it does not step
let main():i32 {
    var s:cstr := "hi"
    s++
    return 0
}
// error: a cstr is text, not a cursor (#52): walk it with 'for c in s', index it, or step a 'var p:u8^ := s'
