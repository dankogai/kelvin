// an Optional has none and some, not err (#75)
let main():i32 {
    var o:i64? = err(3)
    return 0
}
// error: an Optional has no case 'err': its cases are none and some; a Result has ok and err
