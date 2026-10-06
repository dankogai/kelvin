// error: 'i64' is a type already: write 'i64', not 'i64.type'
let main():i32 {
    var c:i64.type = 3;
    return 0;
}
