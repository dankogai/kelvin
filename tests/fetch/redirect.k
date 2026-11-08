// fetch(url) follows redirects (#482), as JS's does: 301, 302, 303, 307
// and 308, a Location absolute, from the root or relative, its . and ..
// removed, up to 20; the Response's url is where it ended, and redirected
// says it moved
#import <fetch>
let get(base:cstr, path:cstr) {
    var r = fetch(`${base}${path}`)
    if let res = r {
        println(path, ": ", res.status, " ", res.redirected, " ", res.url)
    } else {
        println(path, ": ", r.err.message)
    }
}
let main(argc:int32, argv:u8^^):int32 {
    let base:cstr := argv[1]
    get(base, "/redirect")
    get(base, "/dir/relative")
    get(base, "/twice")
    get(base, "/loop")
    return 0
}
// out: /redirect: 200 true BASE/hello
// out: /dir/relative: 200 true BASE/hello
// out: /twice: 200 true BASE/hello
// out: /loop: fetch: more than 20 redirects, the last to /loop
