// error: 'p' is a let parameter and cannot change; write 'var p' in the parameter list
// parameters are lets unless written var: f(var p: u8^)
let f(p:u8^) { p := p.next; }
let main():i32 { return 0; }
