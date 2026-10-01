/* fmt() from C: the cases from the review of #18 */
#include <kelvin_prelude.h>
#include <stdio.h>
#include <string.h>
#include <complex.h>
#define FM(v, f) _Generic((v), KV_METHOD_fmt default: kv_fmt_ptr)(v, f)
#define CHK(got, want) do { kv_String g_ = (got); if (strcmp((char*)g_.bytes, want)) printf("MISMATCH %s: got [%s] want [%s]\n", #got, g_.bytes, want); else n_ok++; } while (0)
int main(void) {
    int n_ok = 0; char w[600];
    int a = -1; signed char b = -1; short c = -2; long long ll = -1; unsigned u8v = 5;
    CHK(FM(a, "%x"), "ffffffff"); CHK(FM(b, "%x"), "ff"); CHK(FM(a, "%u"), "4294967295"); CHK(FM(c, "%o"), "177776");
    CHK(FM(ll, "%x"), "ffffffffffffffff");
    __int128 m = -1; __int128 big = -(__int128)9223372036854775807LL - 2; unsigned __int128 ub = ((unsigned __int128)1 << 64);
    CHK(FM(m, "%x"), "ffffffffffffffffffffffffffffffff"); CHK(FM(big, "%x"), "ffffffffffffffff7fffffffffffffff");
    CHK(FM(ub, "%.3d"), "18446744073709551616"); CHK(FM(ub, "%025d"), "0000018446744073709551616"); CHK(FM(ub, "%#x"), "0x10000000000000000"); CHK(FM(ub, "%+d"), "+18446744073709551616");
    CHK(FM(3.141592653589793, "%a"), "0x1.921fb54442d18p+1");
    CHK(FM(-9223372036854775808.0, "%d"), "-9223372036854775808");
    CHK(FM(65, "%05c"), "    A"); CHK(FM(65, "%#d"), "65"); CHK(FM(5, "%99999999999d"), "<invalid format>");
    CHK(FM(u8v, "%+d"), "+5"); CHK(FM((_Bool)1, "%f"), "1.000000"); CHK(FM((_Bool)1, "%5s"), " true");
    CHK(FM(42, "%.2f"), "42.00"); CHK(FM(255, "%#x"), "0xff"); CHK(FM(-42, "%5d"), "  -42"); CHK(FM(-42, "%-6d|"), "-42   |");
    CHK(FM(0, "%.0d"), ""); CHK(FM(0, "%#.0o"), "0"); CHK(FM(8, "%#o"), "010"); CHK(FM(-5, "%08.3d"), "    -005"); CHK(FM(5, "% d"), " 5");
    CHK(FM(42, "100%% %d%%"), "100% 42%"); CHK(FM(42, "%d %d"), "<invalid format>"); CHK(FM(42, "%ld"), "<invalid format>");
    CHK(FM("hi", "%-5s|"), "hi   |"); CHK(FM("hello", "%.3s"), "hel");
    double _Complex z = 1.0 + 2.0 * I; CHK(_Generic((z), KV_METHOD_toString default: kv_toString_ptr)(z), "1+2i");
    /* long formats: the text is kept (up to 255 bytes), never rejected or cut mid-escape */
    memset(w, 'a', 511); w[511] = 0; strcat(w, "%d");
    { kv_String r = FM(7, w); if (strlen((char *)r.bytes) == 255 && r.bytes[0] == 'a') n_ok++; else printf("MISMATCH long text\n"); }
    char *sp = "%"; char long_fmt[2000] = "%"; for (int i = 0; i < 300; i++) strcat(long_fmt, "-"); strcat(long_fmt, "d"); for (int i = 0; i < 300; i++) strcat(long_fmt, "%%"); (void)sp;
    { kv_String r = FM(7, long_fmt); if (strlen((char *)r.bytes) == 255 && r.bytes[0] == '7' && r.bytes[1] == '%' && r.bytes[2] == '%') n_ok++; else printf("MISMATCH long escapes\n"); }
    printf("%d checks ok\n", n_ok); return 0;
}
// out: 36 checks ok
