// $"" is the type String (#616); a type has no text
let main():int32 {
    var s:$"x" = $"y"
    return 0
}
// error: $"" is the type String; a type has no text: write $"" or String
