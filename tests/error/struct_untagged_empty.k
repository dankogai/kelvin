// a struct with no tag has members (#59)
let main():i32 {
    var e:{} = {}
    return 0
}
// error: a struct with no tag names its members: {x:f64, y:f64}
