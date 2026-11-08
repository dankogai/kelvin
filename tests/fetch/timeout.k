// fetch's timeout (#486): RequestInit's timeout, seconds as an f64, bounds
// the whole request, redirects and a body that trickles in, all; 0, left
// out, is none, where 60 seconds of silence is the most a wait may be; a
// timeout below 0, or NaN, is an Error
#import <fetch>
let get(base:cstr, path:cstr, seconds:f64) {
    var r = fetch(`${base}${path}`, (RequestInit){.timeout = seconds})
    if let res = r {
        var t = res.text() ?? $""
        println(path, " ", seconds, ": ", res.status, " ", t.trim())
    } else {
        println(path, " ", seconds, ": ", r.err.message)
    }
}
let main(argc:int32, argv:u8^^):int32 {
    let base:cstr := argv[1]
    get(base, "/slow", 0.25)
    get(base, "/slow", 5.0)
    get(base, "/slow", 0.0)
    get(base, "/trickle", 0.75)
    get(base, "/trickle", 5.0)
    get(base, "/slowredirect", 1.25)
    get(base, "/slowredirect", 5.0)
    get(base, "/hello", -1.0)
    let zero:f64 = argc > 99 ? 1.0 : 0.0   // a zero the compiler cannot fold
    get(base, "/hello", zero / zero)
    get(base, "/hello", 1.0 / zero)
    return 0
}
// out: /slow 0.25: fetch: the timeout of 0.25 seconds passed
// out: /slow 5.0: 200 late
// out: /slow 0.0: 200 late
// out: /trickle 0.75: fetch: the timeout of 0.75 seconds passed
// out: /trickle 5.0: 200 xxxxxxxxxx
// out: /slowredirect 1.25: fetch: the timeout of 1.25 seconds passed
// out: /slowredirect 5.0: 200 late
// out: /hello -1.0: fetch: a timeout is a number of seconds, 0 for none, and this is -1.0
// out: /hello nan: fetch: a timeout is a number of seconds, 0 for none, and this is nan
// out: /hello inf: 200 hello, fetch
