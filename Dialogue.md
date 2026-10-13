

### 148. `j["key"]` and `j[i]`

> now add `j["key"]` and `j[i]` straight on a JSON

**Claude** added #117 as a rule of enums with values: `v[k]` goes
through the case that is a Dictionary when `k` is text, and the Array
case when it is an integer, so `j["tags"][1].number` reads a path and
`j["n"] = JSON.number(4.0)` writes one, checked as the case and the
index are. On the way, assigning into an element of an Array of such
an enum turned out to want a helper that was never written; it is
now. Details are provisional P129.

There are 666 tests, and all pass with clang and with gcc 15.
