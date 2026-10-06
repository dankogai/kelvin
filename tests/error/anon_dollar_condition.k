// error: in the head of if, while or for, a '{' after a call starts the body
let some(f:(i64):bool):bool { return f(1); }
let main():i32 {
    if some() { $0 > 0 } {
        println(1);
    }
    return 0;
}
