// error: '??' in '#inline C' is a trigraph of C, which Kelvin does not have (#220)
#inline C {
    static int either(int a, int b) { return a ??! b; }
}
