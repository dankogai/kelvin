// if let names a case the type has (#78)
let parse(s:cstr):Result<i64, String> { return i64(s) }
let main():i32 {
    var r = parse("1")
    if let oops(e) = r { }
    return 0
}
// error: Result<i64, String> has no case 'oops': its cases are
