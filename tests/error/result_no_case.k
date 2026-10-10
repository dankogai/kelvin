// a Result's cases are ok and err (#75)
let main():i32 {
    var w = Result<i64, String>.nope(1)
    return 0
}
// error: Result<i64, String> has no case 'nope': the cases are ok, err
