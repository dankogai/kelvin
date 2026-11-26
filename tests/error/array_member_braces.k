// braces where a member that is an array goes (#48, #772), which kc
// said of an array that is not assigned
struct grid { cells:[int64](2) }
let main():int32 {
    var g:grid = {{1, 2}}
    return 0
}
// error: an array is initialized with '[...]', not '{...}' (#48)
