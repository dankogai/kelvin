let printf(fmt:const uint8^, ...):int32;

struct sample {
    ok:bool;
    x:float32;
    y:float64;
};

let is_even(n:int64):bool {
    return n % 2 == 0;
}

let main():int32 {
    var s:struct sample = {true, 1.5, 2.25};
    var done:bool = false;
    printf("%d %d %d\n", int32(sizeof(float32)), int32(sizeof(float64)), int32(sizeof(bool)));
    printf("%.2f %.2f\n", s.x * 2, s.y / 3);
    printf("%d %d %d\n", s.ok, done, is_even(10) && !is_even(7));
    var third:float64 = 1.0 / 3;
    printf("%.4f\n", float32(third));

    // true and false infer bool (#24), so `flag` is a condition as it is
    var flag = true;
    var off = false;
    while flag {
        flag = off;
    }
    println(flag, " ", sizeof(flag), " ", true.cstr);
    return 0;
}
// out: 4 8 1
// out: 3.00 0.75
// out: 1 0 1
// out: 0.3333
// out: false 1 true
