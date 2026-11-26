// c += 1 of a cstr, as c++ is (#52, #769), which kc built
let main():int32 {
    var c:cstr := "abc"
    c += 1
    return 0
}
// error: a cstr is text, not a cursor (#52): walk it with 'for c in s', index it, or step a 'var p:u8^ := s'
