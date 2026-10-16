// if let names a case the type has (#78)
let parse(s:cstr):Result<int64, String> { return int64(s) }
let main():int32 {
    var r = parse("1")
    if let oops(e) = r { }
    return 0
}
// error: Result<i64, String> has no case 'oops': its cases are
