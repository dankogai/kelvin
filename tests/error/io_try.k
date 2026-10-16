// IO(path, mode) is the IO straight (#109), nothing to try: ask f.error
#import <IO>
let read(path:cstr):Result<int64, int32> {
    let f = try IO(path)
    return 0
}
let main():int32 { return 0 }
// error: 'try' takes a Result or an Optional, and this is IO
