

### 158. `${xs}` in a template

> now add `${xs}` of an Array in a template

**Claude** added #125: a template shows an Array, and a Dictionary and
a Set by the same printer, as `print` does since #123; cut to the
template's room as a long string value is, and whole in `` $`...` ``.
Details are provisional P137.

There are 683 tests, and all pass with clang and with gcc 15.
