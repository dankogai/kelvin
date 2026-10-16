// try of a place whose value owns would move it out (#76)
let name(n:int64):Result<String, int32> { return $`#${n}` }
let f(n:int64):Result<String, int32> {
    var r = name(n)
    var s = try r
    return s
}
let main():int32 { return 0 }
// error: 'try' would move the String out of 'r', which keeps it: try the call itself, 'try r.copy()', or 'if let'
