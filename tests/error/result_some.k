// error: a Result has no case 'some': write ok(v), or err(e) (#224)
let parse(s:cstr):Result<int64, String> {
    return some(42)
}
