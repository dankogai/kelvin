// error: an anonymous function cannot use 'self' of the function around it
struct list { xs:i64[3]; };
list.each(f:(i64)) { for x in self.xs { f(x); } }
list.dump() { self.each() { print(self.xs[0]) } }
main():i32 { return 0; }
