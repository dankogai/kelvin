// f.string is a Result<String, i64> (#406): try passes its err up only
// to a function whose err is an i64 too
#import <IO>
let read(path:cstr):Result<String, int32> {
    let f = IO(path)
    return try f.string
}
let main():int32 { return 0 }
// error: 'try' passes the 'err' up as it is, and it is i64 where this function's is i32
