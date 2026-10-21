// ?? of a value that owns (#250) falls back to one of its type: another
// is Kelvin's error, not C's
let main():int32 {
    var s:String? = none
    var y = s ?? 5
    return 0
}
// error: '??' of String? falls back to a String? or a String, and this is a number
