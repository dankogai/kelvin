// an enum with values is indexed through a Dictionary or an Array case (#117)
enum shape { none; dot: int64; name: String }
let main():i32 {
    var s = shape.dot(1)
    println(s["x"].cstr)
    return 0
}
// error: shape is not indexed with text: no case of it is a Dictionary or an Array
