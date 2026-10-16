// an enum with an Array case only is indexed with an integer (#117)
enum list { none; items: Array<int64> }
let main():i32 {
    var l = list.items($[1, 2])
    println(l["x"])
    return 0
}
// error: list is not indexed with text: its Array case takes an integer
