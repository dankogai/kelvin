// a cstr's bytes never change (#52)
let main():i32 {
    var s:cstr := "I love to hate C"
    s[0] = 'U'
    return 0
}
// error: a cstr is immutable (#52): to change text, copy it into a byte array, 'var t:[u8](n)' and strcpy, or write through a 'var p:u8^ := s'
