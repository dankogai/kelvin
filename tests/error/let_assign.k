// error: 'k' is a let and cannot change; declare it with var
let main():i32 {
    let k = 42;
    k += 1;
    return 0;
}
