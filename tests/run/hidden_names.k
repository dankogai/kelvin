// what kelvinc writes into the C is named _kv_, the name it comes from,
// and its kind; a repeat in a function is numbered from 1, and a name
// with no source from 0 (#38)
struct point { x: i64; y: i64 }

let point.scaled(k:i64):point {
    let f:(i64):i64 := { $0 * 2 }
    return (point){f(self.x) * k, f(self.y) * k}
}

let apply(x:i64, f:(i64):i64):i64 { f(x) }
let twice:(i64):i64 := { $0 * 2 }
struct holder { a: u8[sizeof(apply(1) { $0 + 1 })] }

let main():i32 {
    let n:i64 = 255
    let p:point = {1, 2}
    var xs:i64[3] = {1, 2, 3}
    print(n.hex, " ", n.dec, " ", (n + 1).hex, " ", p.cstr, " ", p.scaled(2).x)
    for i in 0..<2 {
        print(" ", i)
    }
    for i in 0...1 {
        print(" ", i)
    }
    for _ in 0..<1 {
        print(" _")
    }
    for x in xs {
        print(" ", x)
    }
    println(" ", apply(1) { $0 + 1 }, " ", apply(2) { $0 + 1 }, " ", twice(3), " ", `${n}`)
    return 0
}
// out: +0xff +255 +0x100 {x: 1, y: 2} 4 0 1 0 1 _ 1 2 3 2 3 6 255
// c: uint8_t _kv_n_text[36], _kv_n_text1[41], _kv_text0[36], _kv_p_text[_kv_point_cstr_size]
// c: for (int64_t _kv_i_count = 0, _kv_i_end = 2; _kv_i_count < _kv_i_end; _kv_i_count++)
// c: _kv_i_count1 = 0, _kv_i_end1 = 1, _kv_i_go = _kv_i_count1 <= _kv_i_end1; _kv_i_go;
// c: _kv_count0 = 0, _kv_end0 = 1
// c: *_kv_x_ptr = *_kv_x_array
// c: static inline int64_t _kv_main_fn(__attribute__((unused)) int64_t _kv_arg0)
// c: apply(2, _kv_main_fn1)
// c: _kv_point_scaled_fn
// c: _kv_twice_fn
// c: _kv_holder_fn
// c: static inline uint8_t *_kv_point_cstr(struct point self, uint8_t *_kv_buf)
// c: __auto_type _kv_p_self
// c: char _kv_template0[sizeof "" + 20];
// c: KV_TEMPLATE_BUILD(_kv_build0, _kv_template0); __auto_type _kv_value0 = ((void)0, (n));
