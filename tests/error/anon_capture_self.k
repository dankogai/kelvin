// error: an anonymous function cannot use 'self' of the function around it
struct list { xs:[i64](3); };
let list.each(f:(i64)) { for x in self.xs { f(x); } }
let list.dump() { self.each() { print(self.xs[0]) } }
let main():i32 { return 0; }
