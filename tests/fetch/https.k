// fetch(url) over HTTPS (#482), where libkfetch was built with HAS_SSL=1:
// the certificate checked against the trusted ones, here SSL_CERT_FILE's,
// for the address or the name in the URL; a redirect stays on TLS; a
// certificate not trusted is an Error
// needs: ssl
#import <fetch>
#import <IO>
#import <OS>
let slowly(url:String, signal:AbortSignal):Result<Response, Error> { fetch(&url, (RequestInit){.signal = signal}) }
let get(base:cstr, path:cstr) {
    var r = fetch(`${base}${path}`)
    if let res = r {
        var t = res.text() ?? $"(no text)"
        println(path, ": ", res.status, " ", res.redirected, " ", res.url, " [", t.trim(), "]")
    } else if r.err.message.starts("fetch: the certificate of 127.0.0.1 is not trusted: ") {
        println(path, ": not trusted")   // OpenSSL's words after it differ by version
    } else {
        println(path, ": ", r.err.message)
    }
}
let main(argc:int32, argv:u8^^):int32 {
    let tls:cstr := argv[2]
    let bad:cstr := argv[3]
    get(tls, "/hello")
    get(tls, "/chunked")
    get(tls, "/redirect")
    get(bad, "/hello")
    var slow = fetch(`${tls}/slow`, (RequestInit){.timeout = 0.25})   // a timeout over TLS (#486)
    println(slow.err.message)
    var c = AbortController()                                       // an abort over TLS (#487)
    var t = async slowly($`${tls}/slow`, c.signal)
    OS.sleep(0.25)
    c.abort("over TLS")
    var a = await t
    println(a.err.message)
    var st = fetch(`${tls}/lines`, (RequestInit){.stream = true})   // a body that streams over TLS (#488)
    if let res = st {
        for r in res.stream.lines {
            if let line = r { print(line, "|") }
        }
        println(" ", res.streamError)
    }
    var jar = CookieJar()                                           // a Secure cookie, kept over https alone (#489)
    var sc = fetch(`${tls}/setcookie`, (RequestInit){.cookies = jar})
    let plain = jar.getCookieString(`http${&tls[5]}`)
    println(sc.ok.status, " [", jar.getCookieString(tls), "] [", plain, "]")
    return 0
}
// out: /hello: 200 false TLSBASE/hello [hello, fetch]
// out: /chunked: 200 false TLSBASE/chunked [chunk one, chunk two]
// out: /redirect: 200 true TLSBASE/hello [hello, fetch]
// out: /hello: not trusted
// out: fetch: the timeout of 0.25 seconds passed
// out: fetch: aborted: over TLS
// out: one|two|three| none
// out: 200 [a=1; b=2; c=3; s=1] [a=1; b=2; c=3]
