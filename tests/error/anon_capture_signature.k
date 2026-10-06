// error: an anonymous function cannot use 'k' of the function around it
let k = 2;
let main():i32 {
    let k = 3;
    let sum := { (a:i64[k]):i64 in a[0] };
    return 0;
}
