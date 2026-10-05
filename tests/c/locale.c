/* print shows floats with '.' whatever the C locale's decimal point is.
   This needs a locale with ',' (macOS has them; a bare Linux image may
   have none, and then the C locale's '.' is checked) */
#include <kelvin_prelude.h>
#include <locale.h>
#include <string.h>

int main(void)
{
    static const char *const names[] = {"de_DE.UTF-8", "de_DE", "fr_FR.UTF-8", "fr_FR"};
    for (size_t i = 0; i < sizeof names / sizeof names[0]; i++)
        if (setlocale(LC_NUMERIC, names[i]) && strcmp(localeconv()->decimal_point, ".") != 0)
            break;
    println(1.5, " ", -1.5e16, " ", 0.0015, " ", 2.5e-8, " ", 1.5e30f, " ", -0.25f, " ", 1.5e300L);
    kv_template t = {0};
    KV_TEMPLATE_VALUE(&t, 1.5e16);
    println((const char *)t.text);
    kv_template_free(&t);
    return 0;
}
// out: 1.5 -1.5e+16 0.0015 2.5e-08 1.5e+30 -0.25 1.5e+300
// out: 1.5e+16
