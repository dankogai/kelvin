// C23's typeof_unqual is x.type (#398), whose own qualifiers do not come along
let main():i32 {
    let n = 1
    var x:typeof_unqual(n) = 2
    return 0
}
// error: 'typeof_unqual' is a C compiler keyword; use x.type, whose own qualifiers do not come along
