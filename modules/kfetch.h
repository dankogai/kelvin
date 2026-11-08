/* kfetch.h - the engine of #import <fetch> (#482, #483): JS's fetch(url,
   init) over HTTP/1.1, in runtime/fetch.c, linked as libkfetch. HTTPS is there
   where libkfetch was built with HAS_SSL=1, through OpenSSL, whose flags
   modules/libkfetch.link gives the program's link. modules/fetch.k wraps
   it. */
#ifndef KFETCH_H
#define KFETCH_H
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include "kelvin_prelude.h"

/* a request of url, following redirects or not as redirect says, 0 to
   follow up to 20, 1 to give the redirect itself, 2 to make it an error:
   method, "" for GET; the caller's headers as name\0value\0 pairs; the
   body, empty for none; timeout, seconds over the whole request, 0 for
   none, where 60 seconds of silence is the most a wait may be; signal, an
   AbortSignal's id, 0 for none. True with the status, its text, the URL it ended
   at, the redirects followed, the headers (read by kfetch_header) and the
   body; false with what went wrong in error */
bool kfetch_request(const uint8_t *url, const uint8_t *method, const kv_bytes *headers_given,
                    const kv_bytes *body_given, int64_t redirect, double timeout, int64_t signal,
                    int64_t *status, kv_string *status_text, kv_string *final_url, int64_t *redirects,
                    kv_bytes *headers, kv_bytes *body, kv_string *error);
/* an AbortController's state (#487), kept for the program's life: a new
   one's id, 1 up; abort it, with a reason or "" for none, which shuts
   down the socket of a fetch that watches it; whether it was aborted */
int64_t kfetch_abort_new(void);
void kfetch_abort(int64_t id, const uint8_t *reason);
bool kfetch_aborted(int64_t id);
/* header i of what kfetch_get gave, its name lowercased, as JS's
   Headers; false past the last */
bool kfetch_header(const kv_bytes *headers, int64_t i, kv_string *name, kv_string *value);
/* whether libkfetch was built with HTTPS, HAS_SSL=1 */
bool kfetch_has_ssl(void);

#endif
