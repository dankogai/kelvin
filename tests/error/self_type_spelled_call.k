// a type with no tag has no name to call a function by, so Self there is a type only (#140)
extend enum{nothing, just: int64} {
    let f():i64 { Self.g() }
}
let main():i32 { return 0 }
// error: 'Self' here is a type with no tag, which has no name to call a function by
