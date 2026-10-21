// error: an Array has no '.mapWithKey': it is a Dictionary's, whose function takes each key; write '.map'
let main():int32 {
    var xs:$[int64] = $[]
    var ys = xs.mapWithKey { k, v in v }
    return 0
}
