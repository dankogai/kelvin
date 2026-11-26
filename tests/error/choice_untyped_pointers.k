// a choice of two pointers, no type written (#777), which kc built
let main():int32 {
    var x:int64 = 1
    var y:int64 = 2
    var p := true ? &x : &y
    return 0
}
// error: 'p' needs a type: write 'p:T = ...' (or 'p:T := ...' for a reference)
