// an overload with a result and one without differ in their results only (#41)
show(n:i64):i64 { n }
show(n:i64) { }
main():i32 { return 0 }
// error: 'show' is declared with these parameter types already, with another result: overloads differ in their parameter types
