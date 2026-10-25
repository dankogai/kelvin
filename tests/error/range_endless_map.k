// a Range written without an end has no end for '.map' to walk to (#373)
let main():int32 {
    let a = (0...).map { $0 * 2 }
    return 0
}
// error: '.map' walks a Range to its end, and 0... has none: take the first few, as in '.prefix(10).map', or walk it lazily, '.lazy.map'
