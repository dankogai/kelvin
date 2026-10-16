// main is C's, with one form (#41)
let main():int32 { return 0 }
let main(argc:int32, argv:cstr^):int32 { return 0 }
// error: main cannot be overloaded: it is C's main, with one form
