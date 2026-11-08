/* kfetch.h - the engine of #import <fetch> (#482): JS's fetch(url) as a GET
   over HTTP/1.1, in runtime/fetch.c, linked as libkfetch. HTTPS is there
   where libkfetch was built with HAS_SSL=1, through OpenSSL, whose flags
   modules/libkfetch.link gives the program's link. modules/fetch.k wraps
   it. */
#ifndef KFETCH_H
#define KFETCH_H
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include "kelvin_prelude.h"

/* a GET of url, following up to 20 redirects: true with the status, its
   text, the URL it ended at, the redirects followed, the headers (read by
   kfetch_header) and the body; false with what went wrong in error */
bool kfetch_get(const uint8_t *url, int64_t *status, kv_string *status_text, kv_string *final_url,
                int64_t *redirects, kv_bytes *headers, kv_bytes *body, kv_string *error);
/* header i of what kfetch_get gave, its name lowercased, as JS's
   Headers; false past the last */
bool kfetch_header(const kv_bytes *headers, int64_t i, kv_string *name, kv_string *value);
/* whether libkfetch was built with HTTPS, HAS_SSL=1 */
bool kfetch_has_ssl(void);

#endif
