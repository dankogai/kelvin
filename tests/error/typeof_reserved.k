// typeof is a reserved word (#398)
let main():i32 {
    var typeof = 1
    return 0
}
// error: expected a name, found 'typeof'
