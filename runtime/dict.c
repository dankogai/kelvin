/* dict.c - Dictionary<K, V> (#65): the hash of a key, a text key's
   equality with a stored String, and a missing key, which ends the
   program. The Dictionary itself is instantiated in the program's C by
   the prelude's KV_DICT, per key and value type. */
#include "kelvin_prelude.h"

#include <stdio.h>
#include <string.h>

/* a 64-bit mix (splitmix64's finalizer) */
size_t kv_hash_int(uint64_t x) {
    x ^= x >> 33;
    x *= 0xff51afd7ed558ccdULL;
    x ^= x >> 33;
    x *= 0xc4ceb9fe1a85ec53ULL;
    x ^= x >> 33;
    return (size_t)x;
}

/* FNV-1a over the bytes of a NUL-terminated text */
size_t kv_hash_text(const void *s) {
    uint64_t h = 0xcbf29ce484222325ULL;
    for (const unsigned char *p = s; *p; p++) {
        h ^= *p;
        h *= 0x100000001b3ULL;
    }
    return (size_t)h;
}

bool kv_string_eq_text(const kv_string *s, const void *t) {
    size_t n = strlen(t);
    return s->b.count == n && (n == 0 || !memcmp(s->b.at, t, n));
}

void kv_dict_missing_int(long long k) {
    char msg[96];
    snprintf(msg, sizeof msg, "key %lld is not in the Dictionary", k);
    kv_array_fail(msg);
}

void kv_dict_missing_text(const void *k) {
    char msg[160];
    snprintf(msg, sizeof msg, "key '%.100s' is not in the Dictionary", (const char *)k);
    kv_array_fail(msg);
}
