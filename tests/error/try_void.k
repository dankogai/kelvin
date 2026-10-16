// try in a function with no result (#76)
let parse(s:cstr):Result<int64, String> { return int64(s) }
let show(s:cstr) {
    println(try parse(s))
}
let main():int32 { return 0 }
// error: 'try' passes the 'err' up, and this function has no result: give it Result<i64, String>
