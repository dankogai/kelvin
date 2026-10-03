// error: names starting with kv_ are kelvinc's own, in the C it writes: rename 'kv_i1'
main():i32 {
    for kv_i1 in 0..<2 {
        println(kv_i1);
    }
    return 0;
}
