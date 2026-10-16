// error: expected ';' or a new line after the trailing function, before what follows
let each(n:int64, f:(int64)) { for i in 0..<n { f(i); } }
var total:int64 = 0;
let main():int32 {
    each(2) { total += $0 } each(2) { total += $0 * 10 }
    return 0;
}
