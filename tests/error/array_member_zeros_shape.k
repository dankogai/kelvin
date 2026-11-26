// zeros of another element where a member that is an array goes (#773)
struct grid { cells:[int64](2) }
let main():int32 {
    var g:grid = {[float64](2)}
    return 0
}
// error: 'cells' of grid is a [i64](2), and this is [f64](2)
