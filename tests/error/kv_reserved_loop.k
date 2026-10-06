// error: names starting with _kv_ are kelvinc's own, in the C it writes: rename '_kv_i_count'
let main():i32 {
    for _kv_i_count in 0..<2 {
        println(_kv_i_count);
    }
    return 0;
}
