// Results in practice: C hands a value back through a pointer and an
// error code or errno beside it; a Kelvin function returns both as one
// Result<T, U>, since a struct has always been a value. Wrappers of
// timespec_get, fopen, strtol and getenv, and errors passed up by hand.
#import <stdio.h> as C
#import <stdlib.h> as C
#import <string.h> as C
#import <errno.h> as C
#import <time.h> as C
struct timespec;

// int timespec_get(struct timespec *ts, int base): fills ts, 0 on failure
let now():Result<timespec, i32> {
    var ts:timespec
    if timespec_get(&ts, TIME_UTC) == 0 { return err(EINVAL) }
    return ts                              // a T becomes ok(T)
}

// FILE *fopen(...): NULL and errno on failure
let open(path:cstr, mode:cstr):Result<FILE^, i32> {
    let f:FILE^ := fopen(path, mode)
    if f.isNull { return err(errno) }
    return f
}

// char *getenv(...): NULL when unset; no reason, so an Optional
let env(name:cstr):cstr? {
    let v:cstr := getenv(name)
    if v.isNull { return none }
    return v
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

// an err passed up by hand: what a future `try` would write for us
let sumOf(path:cstr):Result<i64, i32> {
    var r = open(path, "r")
    if r.is(err) { return err(r.err) }
    var sum:i64 = 0
    var line = [u8](64)
    while fgets(line, line.size, r.ok) != nullptr {
        line[strcspn(line, "\n")] = 0
        if let n = number(line) { sum += n }
    }
    fclose(r.ok)
    return sum
}

let main():i32 {
    if let ts = now() { println("clock ", ts.tv_sec > 0) }
    var missing = sumOf("/no/such/file")
    switch missing {
    case ok: println(missing.ok)
    case err: println("sum: ", strerror(missing.err))
    }
    var unset = env("KELVIN_NO_SUCH_VARIABLE")
    println(unset ?? "unset" as cstr, " ", env("PATH").is(some))
    var f:FILE^ := tmpfile()
    fputs("40\n2\nx\n9 lives\n99999999999999999999\n", f)
    rewind(f)
    var total:i64 = 0
    var line = [u8](64)
    while fgets(line, line.size, f) != nullptr {
        line[strcspn(line, "\n")] = 0
        var r = number(line)
        switch r {
        case ok: total += r.ok
        case err: println(r.err)
        }
    }
    fclose(f)
    println("total ", total)
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
// c: struct _kv_res_FILEp_i32 open(
// c: struct _kv_opt_cstr env(
