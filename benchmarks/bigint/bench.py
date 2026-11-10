# bench.py - Python's int, the cases of bench.k, best of 3.  Each line is a
# case's id, its best time in seconds and its result mod 1000000007.
import math
import sys
import time

if hasattr(sys, "set_int_max_str_digits"):   # 3.11 and later limit int <-> str
    sys.set_int_max_str_digits(0)

DIGITS = "9876543210" * 1000      # 10,000 decimal digits
A = int(DIGITS)
B = A + 1
BIG = A * A                       # about 20,000 digits
POW = 2**100000                   # 30,103 digits
X = 7**1183                       # coprime, about 1,000 digits
Y = 3**2093
MOD = int("9876543210" * 62) + 1  # about 2060 bits, odd
BASE = MOD - 12346
EXP = MOD >> 1


def case_sum():
    s = 0
    for i in range(1, 100001):
        s += i
    return s


def case_fib():                   # 10,000 additions: a is fib(10000)
    a, b = 0, 1
    for _ in range(5000):
        a += b
        b += a
    return a


def case_factorial():
    f = 1
    for i in range(2, 1001):
        f *= i
    return f


def case_power():
    return 2**100000


def case_mul():
    r = 0
    for _ in range(100):
        r = A * B
    return r


def case_div():
    r = 0
    for _ in range(100):
        r = BIG // B
    return r


def case_powmod():
    return pow(BASE, EXP, MOD)


def case_gcd():
    r = 0
    for _ in range(10):
        r = math.gcd(X, Y)
    return r


def case_isqrt():
    r = 0
    for _ in range(10):
        r = math.isqrt(BIG)
    return r


def case_tostr():
    return len(str(POW))


def case_parse():
    r = 0
    for _ in range(100):
        r = int(DIGITS)
    return r


CASES = [("sum", case_sum), ("fib", case_fib), ("factorial", case_factorial),
         ("power", case_power), ("mul", case_mul), ("div", case_div),
         ("powmod", case_powmod), ("gcd", case_gcd), ("isqrt", case_isqrt),
         ("tostr", case_tostr), ("parse", case_parse)]

for name, f in CASES:
    best = math.inf
    check = 0
    for _ in range(3):
        t0 = time.perf_counter()
        r = f()
        t = time.perf_counter() - t0
        best = min(best, t)
        check = r % 1000000007
    print(f"{name}\t{best:.9f}\t{check}")
