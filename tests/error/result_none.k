// a Result has ok and err, not none (#75)
let main():i32 {
    var r:Result<i64, String> = none
    return 0
}
// error: a Result has no case 'none': write err(e), or ok(v)
