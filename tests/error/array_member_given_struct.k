// a struct where a member that is an array goes (#772), which kc said
// of an array that is not assigned
struct pt { x:int64, y:int64 }
struct grid { cells:[int64](2) }
let main():int32 {
    var o:pt = {1, 2}
    var g:grid = {o}
    return 0
}
// error: 'cells' of grid is a [i64](2), and this is pt
