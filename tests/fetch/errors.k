// what fetch(url) cannot do is an err of an Error (#482), its message
// saying why: no connection, no such host, a URL that is not http or https,
// a user in it, a port out of range, no host
#import <fetch>
let get(url:cstr) {
    var r = fetch(url)
    if let err(e) = r {
        println(e.message.starts("fetch: cannot find the host") ? $"fetch: cannot find the host" : e.message.copy())
    } else {
        println(url, ": ", r.ok.status)
    }
}
let main():int32 {
    get("http://127.0.0.1:1/")
    get("http://no-such-host.invalid/")
    get("ftp://example.com/")
    get("http://user@example.com/")
    get("http://127.0.0.1:70000/")
    get("http:///path")
    get("http://example.com/a b")
    var r = fetch("gopher://x")
    println(r)
    return 0
}
// out: fetch: cannot connect to 127.0.0.1 port 1: Connection refused
// out: fetch: cannot find the host
// out: fetch: a URL starts with http:// or https://, and this is ftp://example.com/
// out: fetch: a URL with a user, user@host, is not taken: http://user@example.com/
// out: fetch: this URL's port is not one from 1 to 65535: http://127.0.0.1:70000/
// out: fetch: this URL has no host: http:///path
// out: fetch: a URL has no spaces or control characters: http://example.com/a b
// out: err({message: "fetch: a URL starts with http:// or https://, and this is gopher://x"})
