// main is C's main (#392), never inline
inline let main():i32 { return 0 }
// error: main is C's main, called once: it is not inline
