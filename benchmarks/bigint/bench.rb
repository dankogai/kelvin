# bench.rb - Ruby's Integer, the cases of bench.k, best of 3.  Each line is
# a case's id, its best time in seconds and its result mod 1000000007.

def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

DIGITS = "9876543210" * 1000      # 10,000 decimal digits
A = Integer(DIGITS)
B = A + 1
BIG = A * A                       # about 20,000 digits
POW = 2**100000                   # 30,103 digits
X = 7**1183                       # coprime, about 1,000 digits
Y = 3**2093
MOD = Integer("9876543210" * 62) + 1   # about 2060 bits, odd
BASE = MOD - 12346
EXP = MOD >> 1

CASES = {
  "sum" => -> { s = 0; (1..100000).each { |i| s += i }; s },
  "fib" => -> {                   # 10,000 additions: a is fib(10000)
    a, b = 0, 1
    5000.times { a += b; b += a }
    a
  },
  "factorial" => -> { f = 1; (2..1000).each { |i| f *= i }; f },
  "power" => -> { 2**100000 },
  "mul" => -> { r = 0; 100.times { r = A * B }; r },
  "div" => -> { r = 0; 100.times { r = BIG / B }; r },
  "powmod" => -> { BASE.pow(EXP, MOD) },
  "gcd" => -> { r = 0; 10.times { r = X.gcd(Y) }; r },
  "isqrt" => -> { r = 0; 10.times { r = Integer.sqrt(BIG) }; r },
  "tostr" => -> { POW.to_s.length },
  "parse" => -> { r = 0; 100.times { r = Integer(DIGITS) }; r },
}

CASES.each do |id, f|
  best = Float::INFINITY
  check = 0
  3.times do
    t0 = now
    r = f.call
    t = now - t0
    best = t if t < best
    check = r % 1000000007
  end
  puts "#{id}\t#{format("%.9f", best)}\t#{check}"
end
