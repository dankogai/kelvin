// f.string is a String straight (#107), nothing to try
#import <IO>
let read(path:cstr):Result<String, int32> {
    let f = IO(path)
    return try f.string
}
let main():int32 { return 0 }
// error: 'try' takes a Result or an Optional
