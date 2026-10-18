// xs.sort() (#185) with no comparator compares the elements with <, which
// a struct has only where the program defines it
struct point { x: int64; y: int64 }
let main():int32 {
    var ps = $[(point){2, 1}, (point){1, 5}]
    ps.sort()
    return 0
}
// error: '.sort' compares the elements with <, and struct point has none: give a comparator, '.sort { $0.x < $1.x }', or define one, as in 'let <(a:point, b:point):bool { ... }'
