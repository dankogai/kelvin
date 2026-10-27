// alignas goes before a declaration (#396), not an assignment
let main():i32 {
    var x = 1
    alignas(16) x = 3
    return 0
}
// error: 'alignas' is for a variable or a member: 'alignas(16) var buf:[u8](64)'
