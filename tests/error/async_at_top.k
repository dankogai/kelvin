// async f(x) starts a call in a function (#312)
let one():int64 { 1 }
let t = async one()
let main():int32 { return 0 }
// error: 'async' starts a call on a thread of its own, in a function: write it in one
