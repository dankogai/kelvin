// error: this is i64?, an Optional, where i64 goes: unwrap it with '!', or give a default with '??'
let main():int32 {
    var ages:Dictionary<String, int64> = ${:}
    let n:int64 = ages["ann"]
    return 0
}
