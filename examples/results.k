// Results in practice: C hands a value back through a pointer and an
// error code or errno beside it; a Kelvin function returns both as one
// Result<T, U>, since a struct has always been a value. A wrapper of C's
// timespec_get; a file opened by IO, whose errno is the err; text read
// as a number, or why it is none; and an err passed up by try. What C's
// getenv gives is an Optional already, OS.env's.
#import <IO>
#import <OS>
#import <errno.h> as C
#import <time.h> as C
struct timespec;

// int timespec_get(struct timespec *ts, int base): fills ts, 0 on failure
let now():Result<timespec, i32> {
    var ts:timespec
    if timespec_get(&ts, TIME_UTC) == 0 { return err(EINVAL) }
    return ts                              // a T becomes ok(T)
}

// i64(s) reads as strtol does, 0 for no digits and errno for a range;
// the reason is text, so the error is a String
let number(s:cstr):Result<i64, String> {
    if s.count == 0 { return err($"empty") }
    for c in s {
        if c < '0' || c > '9' { return err($`not a number: ${s}`) }
    }
    errno = 0
    let n = i64(s)
    if errno == ERANGE { return err($`out of range: ${s}`) }
    return n
}

// the numbers of the file at path, a line each, summed, and why each
// other line is none; the errno where the file does not open
let sumOf(path:cstr):Result<i64, i32> {
    let f = IO(path, "r")                  // the IO, straight
    if f.error != 0 { return err(f.error) }
    var sum:i64 = 0
    for r in f.lines {                     // each line a Result too: the String, or where its UTF-8 breaks
        if let line = r {
            var n = number(line.cstr)
            switch n {
            case ok: sum += n.ok
            case err: println(n.err)
            }
        }
    }
    return sum                             // f closes here
}

// a temporary file of the text, and its sum: try passes an err up, the
// errno of a file that could not be made or read
let sumOfText(text:cstr):Result<i64, i32> {
    var t = try OS.mkstemp("results")      // {io: IO, path: String}
    t.io.write(text)
    t.io.close()
    let sum = try sumOf(t.path.cstr)
    OS.remove(t.path)
    return sum
}

let main():i32 {
    if let ts = now() { println("clock ", ts.tv_sec > 0) }
    var missing = sumOf("/no/such/file")
    switch missing {
    case ok: println(missing.ok)
    case err: println("sum: ", IO.strerror(missing.err))
    }
    println(OS.env("KELVIN_NO_SUCH_VARIABLE") ?? "unset", " ", OS.env("PATH").is(some))
    if let total = sumOfText("40\n2\nx\n9 lives\n99999999999999999999\n") { println("total ", total) }
    return 0
}
// out: clock true
// out: sum: No such file or directory
// out: unset true
// out: not a number: x
// out: not a number: 9 lives
// out: out of range: 99999999999999999999
// out: total 42
// c: struct _kv_res_timespec_i32 now(void)
// c: struct _kv_res_i64_String number(
