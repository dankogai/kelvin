// get copies the value, so a value that owns is found, not got (#65)
let main():i32 {
    var d:${i64: String}
    var s = $"k"
    var y = d.get(1, s)
    return 0
}
// error: '.get' copies the value, and String owns: borrow it with '.find(k)', a String^ or nullptr
