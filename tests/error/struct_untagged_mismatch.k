// two structs with no tag are one type only when written alike (#59)
let main():i32 {
    var f:{x:f64} = {1.0}
    var g:{x:f32} = f
    return 0
}
// error: {x: f64} is not {x: f32}: a struct takes a value of its own type, and two structs with no tag are one type only when their members are written alike
