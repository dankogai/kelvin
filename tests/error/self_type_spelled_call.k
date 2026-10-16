// a type with no tag has no name to call a function by, so Self there is a type only (#140)
extend enum{nothing, just: int64} {
    let f():int64 { Self.g() }
}
let main():int32 { return 0 }
// error: 'Self' here is a type with no tag, which has no name to call a function by
