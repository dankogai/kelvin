// an unnamed parameter (#388) has no name to read by: `_` names nothing
let second(_:int64, y:int64):int64 {
    return _ + y
}
let main():int32 {
    println(second(1, 2))
    return 0
}
// error: '_' names nothing to read: it leaves out a name, as of an unnamed parameter or of 'for _ in'
