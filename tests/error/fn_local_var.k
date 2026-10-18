// a function defined inside a function (#180) is a let, as at the top
// level: a var does not declare a function
let main():int32 {
    var twice(n:int64):int64 { n * 2 }
    return int32(twice(0))
}
// error: a function defined inside a function is written 'let twice(...)', in a function's body
