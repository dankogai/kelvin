// IO(path, mode) is the IO straight (#109), nothing to try: ask f.error
let read(path:cstr):Result<i64, i32> {
    let f = try IO(path)
    return 0
}
let main():i32 { return 0 }
// error: 'try' takes a Result or an Optional, and this is IO
