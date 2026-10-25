// a Range written without an end has no upper bound (#375)
let main():int32 {
    let n = (0...).upperBound
    return 0
}
// error: '.upperBound' is a Range's end, and 0... has none: its values go up to its type's largest
