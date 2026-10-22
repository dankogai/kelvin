// a literal is a cstr, text, not a cursor (#52, #282): "a" + 1 stepped
// past the text
let main():int32 {
    println("abc" + 1)
    return 0
}
// error: a cstr is text, not a cursor (#52): walk it with 'for c in s', index it, or step a 'var p:u8^ := s'
