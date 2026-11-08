# fetch: `#import <fetch>`

JS's `fetch(url)` and `fetch(url, init)` over HTTP and HTTPS, giving a `Result<Response, Error>`.

## Synopsis

```swift
#import <fetch>

let main():int32 {
    var r = fetch("https://example.com/")
    if let res = r {
        println(res.status, " ", res.statusText, " ", res.ok)   // 200 OK true
        println(res.url, " ", res.redirected)                     // https://example.com/ false
        println(res.headers["content-type"])                      // some("text/html; charset=utf-8")
        var text = res.text() ?? $"(not UTF-8)"
        println(text.count, " ", res.body.count)
        var j = res.json()                                        // a Result<JSON, Error>
        println(j.is(ok))
    } else {
        println(r.err.message)          // fetch: cannot find the host ..., and the like
    }
    var p = fetch("https://example.com/api", (RequestInit){.method = $"POST",
                  .headers = ${"content-type": $"application/json"}, .body = Bytes("{\"a\": 1}")})
    println(p.is(ok))
    return 0
}
```

## Description

`#import <fetch>` (#482) brings in `fetch(url)`, JS's fetch as a GET,
and `fetch(url, init)` (#483), a request as a `RequestInit` says: it
asks for the URL, follows redirects, and gives what the server
answered, a `Response`, or what went wrong, an `Error`, as a
`Result<Response, Error>` that the caller faces before reading on.

- **`fetch(url)`** takes text, a `cstr`, or a String by reference,
  `fetch(&s)`, of an `http://` or `https://` URL.
  - It waits for the whole answer: there is no Promise. For one on a
    thread of its own, `async` a function that takes the String moved
    in, and `await` it, as [tasks.md](tasks.md) has it; two such
    fetches run at once:
    `let get(url:String):Result<Response, Error> { fetch(&url) }`, then
    `var t = async get($"https://example.com/")` and `var r = await t`.
    - `async fetch(url)` itself would share the text of a `cstr` with
      the thread, which kelvinc refuses.
  - A `#fragment` is not sent, as a browser does not send it.
  - Redirects, 301, 302, 303, 307 and 308, are followed up to 20, as
    JS's are; a Location may be absolute, from the root, or relative,
    with `.` and `..` taken out.
  - The request says `Connection: close`, `Accept: */*`,
    `Accept-Encoding: identity`, so the body comes as it is, and
    `User-Agent: Kelvin-fetch`, the last three where `init` gives none.
- **`fetch(url, init)`** (#483) takes a `RequestInit`, JS's: written in
  the call and moved in, `(RequestInit){.method = $"POST", ...}`, or by
  reference, `&init`; a field left out is empty.
  - `method`, a String, `""` for GET. DELETE, GET, HEAD, OPTIONS, POST
    and PUT are sent in capitals however they are written, as JS's
    fetch does; any other, `patch` among them, as written. CONNECT,
    TRACE and TRACK, and a method that is not a word, are an Error.
  - `headers`, a `Dictionary<String, String>`, sent as written.
    - A name that is not a word, or a value with a line break, is an
      Error.
    - Host, Content-Length, Connection, Transfer-Encoding, Keep-Alive,
      Upgrade, TE and Trailer are fetch's own, and an Error.
    - User-Agent, Accept and Accept-Encoding take the place of
      fetch's.
  - `body`, a `Bytes`, empty for none: `Bytes("text")`, `Bytes(&s)`.
    - It goes with its `Content-Length`; a POST or PUT of none says 0,
      as JS's does.
    - No Content-Type is sent for it: write one in `headers`.
    - A GET or HEAD with a body is an Error.
  - `redirect`, a `Redirect`: `redirectFollow`, the default;
    `redirectManual`, which gives the 3xx itself as the Response; or
    `redirectError`, which makes a redirect an Error.
    - C's enum, whose cases are words of the program, so each begins
      with `redirect`.
  - Following a redirect, as JS's fetch does: a 303 asks again by GET,
    as a 301 or 302 does a POST, without the body and its Content-Type;
    a 307 or 308 asks again as it asked.
    - A redirect to another origin, another scheme, host or port, is
      not sent the Authorization.
  - A HEAD's Response has no body, whatever its Content-Length says.
  - `timeout` (#486), an `f64` of seconds, as Kelvin's time is,
    bounds the whole request: connecting, TLS, sending, receiving, and
    each redirect followed, so a body that trickles in cannot outlast
    it: `(RequestInit){.timeout = 2.5}`.
    - Passed, it is an Error, `fetch: the timeout of 2.5 seconds passed`,
      the seconds printed as Kelvin prints an `f64`.
    - `0`, a field left out, or an infinity, is no deadline of the
      caller's: then a wait of 60 seconds with nothing, to connect or for
      a byte, is the most, and an Error. With a timeout, only it bounds.
    - Below 0, or NaN, it is an Error.
    - Looking up the host's name counts, and the deadline is checked
      after it, but C cannot cut a lookup short, so one that hangs
      waits as long as the system's resolver does.
- **A `Response`** is a struct that owns its parts:
  - `status`, an `i64`, and `statusText`, the status line's text, as
    `404` and `Not Found`; `ok` is whether the status is 200 to 299.
  - `url` is the URL it ended at, after the redirects, and `redirected`
    whether there were any.
  - `headers` is a `Dictionary<String, String>`, its names lowercased,
    as JS's `Headers` reads them: `res.headers["content-type"]` is an
    Optional, `none` where there is no such header.
    - A header that comes more than once is one entry, its values joined
      by `", "`.
    - Text that is not UTF-8, as old servers send, is read as Latin-1.
  - `body` is a `Bytes`, the body as sent: its `Content-Length`, its
    chunks, or all until the connection closes.
  - `res.text()` is the body as a String, or an `Error` where it is not
    UTF-8, as `b.string()` is for a Bytes.
  - `res.json()` (#484) is the body as a `JSON`
    ([json.md](json.md)), or an `Error` where it is not UTF-8, or not
    JSON, with `JSON.parse`'s message:
    `fetch: the body is not JSON: an array: unexpected end of text at 5`.
    - `<fetch>` imports `<JSON>`, so a program has JSON with it;
      importing it too is the same module.
- **An `Error`** is `{message: "..."}`, a struct with a `message`, a
  String that names what went wrong and where:
  - a URL that is not `http://` or `https://`, has a user, a port out of
    1 to 65535, no host, or a space;
  - a host not found, a connection refused, no answer in 60 seconds,
    the caller's timeout passed;
  - a certificate not trusted, or TLS that fails;
  - an answer that is not HTTP/1.1, a body cut short;
  - a method or a header `init` may not have, a GET's body;
  - more than 20 redirects, or one where `redirect` is
    `redirectError`;
  - HTTPS where it is not built in.
  - A status of 404 or 500 is no Error: it is a Response, whose `ok` is
    false, as JS has it.
- **HTTPS** is OpenSSL's, where Kelvin was built with `HAS_SSL=1`, the
  default.
  - The certificate is checked against the system's trusted ones, as
    OpenSSL finds them; `SSL_CERT_FILE` or `SSL_CERT_DIR` in the
    environment names others, as for a test's own.
  - It must be for the host in the URL, a name or an address, and TLS
    is 1.2 or later.
  - Built with `HAS_SSL=0`, an `https://` URL is an Error that says so;
    `http://` works as ever.
- **Building it:** `make` finds OpenSSL with tools/ssl-flags.sh, by
  pkg-config, Homebrew's `openssl@3`, MacPorts', `/usr/local` or the
  system's, and stops where it finds none.
  - `make HAS_SSL=0`, or `HAS_SSL=0` in the environment, builds without
    HTTPS; `SSL_CFLAGS` and `SSL_LIBS` say where OpenSSL is.
  - Changing it builds `libkfetch` again.
- **Not here yet:** a body that streams, an abort by hand, as JS's
  AbortController gives, and cookies.

## Where it lives

`modules/fetch.k`, written in Kelvin over `libkfetch`, runtime/fetch.c,
an HTTP/1.1 client of its own over sockets, with OpenSSL under it for
HTTPS; `make` builds the header and the library with `kelvinc --lib`,
and writes `modules/libkfetch.link`, the flags OpenSSL needs, which
kelvinc adds to the link of a program that imports `<fetch>`.
tests/fetch.sh tests it against a server of its own on 127.0.0.1,
tests/fetch/server.py, HTTPS with a certificate made for the test.

## Properties and methods

| On | Property or method | Gives |
|---|---|---|
| — | `fetch(url)` | a `Result<Response, Error>`: a GET of `url`, a `cstr` or `&s` of a String, following redirects |
| | `fetch(url, init)` | the same of a request as `init`, a `RequestInit` moved in or `&init`, says (#483) |
| `RequestInit` | `.method` | the method, a String, `""` for GET |
| | `.headers` | the request's headers, a `Dictionary<String, String>` |
| | `.body` | the request's body, a `Bytes`, empty for none |
| | `.redirect` | `redirectFollow`, `redirectManual` or `redirectError`, a `Redirect` |
| | `.timeout` | seconds over the whole request, an `f64`, `0` for none (#486) |
| `Response` | `.status` | the status, an `i64` |
| | `.statusText` | the status line's text, a String |
| | `.ok` | whether the status is 200 to 299 |
| | `.url` | the URL it ended at, a String |
| | `.redirected` | whether a redirect was followed |
| | `.headers` | a `Dictionary<String, String>`, names lowercased, repeats joined by `", "` |
| | `.body` | the body, a `Bytes` |
| | `.text()` | the body as a String, or an `Error` where it is not UTF-8: a `Result<String, Error>` |
| | `.json()` | the body as a `JSON`, or an `Error` where it is not UTF-8 or not JSON: a `Result<JSON, Error>` (#484) |
| `Error` | `.message` | what went wrong, a String |
