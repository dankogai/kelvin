// main is C's, with one form (#41)
let main():i32 { return 0 }
let main(argc:i32, argv:cstr^):i32 { return 0 }
// error: main cannot be overloaded: it is C's main, with one form
