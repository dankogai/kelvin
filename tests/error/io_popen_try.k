// IO.popen, IO.exec and IO.pipe() give their IOs straight (#110), nothing
// to try: ask f.error
#import <IO>
let run():Result<i64, i32> {
    let f = try IO.popen("ls", "r")
    return 0
}
let main():i32 { return 0 }
// error: 'try' takes a Result or an Optional, and this is IO
