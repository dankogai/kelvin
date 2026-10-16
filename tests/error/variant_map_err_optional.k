// mapErr is a Result's (#80)
let code(n:int64):int32 { return 1 }
let main():int32 {
    var a:int64? = 3
    var m = a.mapErr(code)
    return 0
}
// error: '.mapErr' is a Result's: an Optional's none carries nothing to map
