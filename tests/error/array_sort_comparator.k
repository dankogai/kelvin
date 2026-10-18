// the comparator of xs.sort (#185) takes two elements and says with a bool
// whether the first goes before the second
let key(n:int64):int64 { -n }
let main():int32 {
    var xs = $[2, 1]
    xs.sort(key)
    return 0
}
// error: '.sort' takes a comparator of two elements, (i64, i64):bool, true where the first goes before the second, and this is (i64):i64
