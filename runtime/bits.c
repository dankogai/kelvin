/* bits.c - the text of a Bits (#387): Bits(0b...), its value in binary
   from its highest bit that is set, which pastes back as Bits(n) */
#include "kelvin_prelude.h"
#include <stdio.h>
#include <string.h>

uint8_t *kv_cstr_bits(kv_bits b, uint8_t *buf) {
    uint8_t digits[64];
    int n = 0;
    do {
        digits[n++] = (uint8_t)('0' + (b.value & 1));
        b.value >>= 1;
    } while (b.value);
    memcpy(buf, "Bits(0b", 7);
    for (int i = 0; i < n; i++)
        buf[7 + i] = digits[n - 1 - i];
    buf[7 + n] = ')';
    buf[8 + n] = 0;
    return buf;
}

void kv_fprint_bits(void *fp, kv_bits b) {
    uint8_t out[73];
    fputs((const char *)kv_cstr_bits(b, out), (FILE *)fp);
}

void kv_print_bits(kv_bits b) { kv_fprint_bits(stdout, b); }

char *kv_template_bits(char *p, size_t max, kv_bits b) {
    uint8_t out[73];
    kv_cstr_bits(b, out);
    return kv_template_bytes(p, max, strlen((const char *)out), out);
}
