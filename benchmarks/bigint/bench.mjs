// bench.mjs - JavaScript's BigInt in Node, the cases of bench.k, best of 3.
// Each line is a case's id, its best time in seconds and its result mod
// 1000000007.  JS has no gcd, isqrt or modular power: they are Euclid's,
// Newton's and square-and-multiply, as Kelvin's BigInt has them.

const now = () => Number(process.hrtime.bigint()) / 1e9;

const DIGITS = "9876543210".repeat(1000);   // 10,000 decimal digits
const A = BigInt(DIGITS);
const B = A + 1n;
const BIG = A * A;                          // about 20,000 digits
const POW = 2n ** 100000n;                  // 30,103 digits
const X = 7n ** 1183n;                      // coprime, about 1,000 digits
const Y = 3n ** 2093n;
const MOD = BigInt("9876543210".repeat(62)) + 1n;   // about 2060 bits, odd
const BASE = MOD - 12346n;
const EXP = MOD >> 1n;

const gcd = (a, b) => {
  while (b !== 0n) [a, b] = [b, a % b];
  return a;
};

const isqrt = (n) => {
  if (n === 0n) return 0n;
  let x = 1n << BigInt(Math.floor((n.toString(2).length + 1) / 2));
  for (;;) {
    const y = (x + n / x) >> 1n;
    if (y >= x) return x;
    x = y;
  }
};

const powmod = (b, e, m) => {
  let r = 1n;
  b %= m;
  while (e > 0n) {
    if (e & 1n) r = (r * b) % m;
    b = (b * b) % m;
    e >>= 1n;
  }
  return r;
};

const CASES = [
  ["sum", () => { let s = 0n; for (let i = 1; i <= 100000; i++) s += BigInt(i); return s; }],
  ["fib", () => {                           // 10,000 additions: a is fib(10000)
    let a = 0n, b = 1n;
    for (let i = 0; i < 5000; i++) { a += b; b += a; }
    return a;
  }],
  ["factorial", () => { let f = 1n; for (let i = 2n; i <= 1000n; i++) f *= i; return f; }],
  ["power", () => 2n ** 100000n],
  ["mul", () => { let r = 0n; for (let i = 0; i < 100; i++) r = A * B; return r; }],
  ["div", () => { let r = 0n; for (let i = 0; i < 100; i++) r = BIG / B; return r; }],
  ["powmod", () => powmod(BASE, EXP, MOD)],
  ["gcd", () => { let r = 0n; for (let i = 0; i < 10; i++) r = gcd(X, Y); return r; }],
  ["isqrt", () => { let r = 0n; for (let i = 0; i < 10; i++) r = isqrt(BIG); return r; }],
  ["tostr", () => BigInt(POW.toString().length)],
  ["parse", () => { let r = 0n; for (let i = 0; i < 100; i++) r = BigInt(DIGITS); return r; }],
];

for (const [id, f] of CASES) {
  let best = Infinity;
  let check = 0n;
  for (let i = 0; i < 3; i++) {
    const t0 = now();
    const r = f();
    const t = now() - t0;
    if (t < best) best = t;
    check = r % 1000000007n;
  }
  console.log(`${id}\t${best.toFixed(9)}\t${check}`);
}
