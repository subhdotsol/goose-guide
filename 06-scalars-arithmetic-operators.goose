// ===================================================================
// 06 - Scalars, arithmetic, operators (syntax.md section 6)
// ===================================================================
import std;   // std provides rem() and div_euclid()

// Used for memberwise struct arithmetic below.
struct V2 { x: f64, y: f64 }

// Helper that prints when it runs: shows && / || short-circuiting.
fn noisy(label: u8[:], v: bool) -> bool {
    print("    (evaluated ", label, ")");
    v
}

fn main() {
    // ---------------------------------------------------------------
    // Arithmetic runs AT THE OPERANDS' OWN WIDTH. No promotion to `int`.
    // ---------------------------------------------------------------
    let byte: u8 = 255;
    let wrapped: u8 = byte + 1;      // an 8-bit add: 255 + 1 wraps to 0 (unsigned always wraps)
    let widened = byte + 42;         // the literal 42 adapts to u8 -> 8-bit add: 297 mod 256 = 41
    let big = byte as i64 + 1000;    // cast first to widen: an i64 add, 1255
    print("u8 wrap: ", wrapped, "  literal adapts to u8: ", widened, "  cast widens: ", big);

    // ---------------------------------------------------------------
    // / truncates toward zero; % is EUCLIDEAN (never negative)
    // ---------------------------------------------------------------
    print("-7 % 3 = ", -7 % 3, "   -7 / 3 = ", -7 / 3, "   7 % -3 = ", 7 % -3);
    // Because / and % don't pair up for negatives, std adds the missing two:
    print("rem(-7, 3) = ", rem(-7, 3), "  (the remainder that goes with /)");
    print("div_euclid(-7, 3) = ", div_euclid(-7, 3), "  (the division that goes with %)");
    // Float % is C's fmod, so it CAN be negative:
    print("-7.0 % 3.0 = ", -7.0 % 3.0);

    // ---------------------------------------------------------------
    // Mixing widths: the rules, in order
    // ---------------------------------------------------------------
    // 1) A literal adapts to the other operand's type:
    let d: u8 = 200;
    let e = d + 100;                 // 100 becomes a u8: 300 mod 256 = 44
    print("literal adapts: ", e);
    // let bad: u8 = 256;            // ERROR: literal 256 does not fit in u8

    // 2) A narrower type widens implicitly into a wider one:
    let small: u8 = 10;
    let wide: i64 = 1000;
    let mixed = small + wide;        // u8 widens to i64: an i64 add
    print("u8 + i64 -> i64: ", mixed);

    // 3) An integer meeting a float takes the float's type:
    let ii: i32 = 3;
    let ff: f32 = 0.5;
    let prod = ii * ff;              // an f32 multiply: 1.5
    print("i32 * f32 -> f32: ", prod);

    // 4) Same-width signed/unsigned (or u64 with signed) is an ERROR: cast one side.
    let ua: u32 = 7;
    let sb: i32 = 3;
    // let c = ua + sb;              // ERROR: u32 and i32 do not unify; cast one side
    let c = ua as i64 + sb;          // OK: an i64 add (`as` binds tightest)
    print("u32 + i32 needs a cast: ", c);

    // Comparing u64 with a signed value is allowed only when the signed side is
    // known non-negative (a literal, .len, or a let bound to one).
    let huge: u64 = 18446744073709551615;
    print("u64 > 5: ", huge > 5);

    // ---------------------------------------------------------------
    // Overflow and division by zero
    // ---------------------------------------------------------------
    var h: u64 = 14695981039346656037;            // unsigned math wraps BY DESIGN:
    for ch in "goose" { h = (h ^ ch) * 1099511628211; }   // FNV-1a hash relies on it
    print("FNV-1a(goose) = ", h);
    // Signed overflow: aborts in a --debug build, wraps in a release build.
    //   var s: i8 = 127; s += 1;    // --debug: abort.  release: -128
    // Division (or %) by zero ALWAYS aborts, in every build:
    //   let z = 0; print(10 / z);   // runtime abort
    // So does i64.min / -1 (the quotient doesn't fit).

    // ---------------------------------------------------------------
    // bool: no int -> bool conversion; && and || short-circuit
    // ---------------------------------------------------------------
    let n = 5;
    // if n { }                      // ERROR: condition must be bool, not i64
    if n != 0 { print("bool: write `n != 0`, not `if n`"); }
    print("  false && ... :");
    let r1 = noisy("left", false) && noisy("right", true);   // right side never runs
    print("  true || ... :");
    let r2 = noisy("left", true) || noisy("right", false);   // right side never runs
    print("  results: ", r1, " ", r2);

    // ---------------------------------------------------------------
    // Floats: f32 -> f64 implicit, int -> float implicit,
    // a float literal adapts to f32 when its destination is f32.
    // ---------------------------------------------------------------
    let f32v: f32 = 0.25;            // literal 0.25 adapts to f32
    let f64v: f64 = f32v;            // f32 -> f64 widens implicitly (never the reverse)
    let from_int: f64 = 3;           // int -> float implicitly: 3.0
    let half = n * 0.5;              // i64 * float literal -> f64: 2.5
    print("floats: ", f32v, " ", f64v, " ", from_int, " ", half);
    // let back: f32 = f64v;         // ERROR: f64 -> f32 needs `as` (see section 7)

    // ---------------------------------------------------------------
    // Arithmetic operators: + - * / %
    // ---------------------------------------------------------------
    let x = 17;
    let y = 5;
    print("arith: ", x + y, " ", x - y, " ", x * y, " ", x / y, " ", x % y);

    // ---------------------------------------------------------------
    // Comparison: < <= > >= == !=   (they produce bool)
    // ---------------------------------------------------------------
    print("compare: ", x < y, " ", x <= 17, " ", x > y, " ", x >= 18, " ", x == 17, " ", x != y);

    // ---------------------------------------------------------------
    // Logical: && || !
    // ---------------------------------------------------------------
    print("logical: ", true && false, " ", true || false, " ", !true);

    // ---------------------------------------------------------------
    // Bitwise: ~ & | ^ << >>   (result keeps the operand's type)
    // ---------------------------------------------------------------
    var flags: u8 = 0;
    flags |= 1 << 1;                 // set bit 1: the constant `1 << 1` adapts to u8 -> 2
    flags |= 4;                      // set bit 2 -> 6
    flags &= ~4;                     // clear bit 2: ~4 adapts to u8 (251) -> 2
    let set = flags & 2 != 0;        // bitwise binds TIGHTER than comparison: (flags & 2) != 0
    print("bitwise: flags = ", flags, " bit1 set? ", set);
    print("  0xF0 & 0x3C = ", 0xF0 & 0x3C, ", 0xF0 | 0x0F = ", 0xF0 | 0x0F, ", 0xFF ^ 0x0F = ", 0xFF ^ 0x0F);
    let sneg: i8 = -16;
    let uval: u8 = 240;
    print("  >> on signed copies the sign bit: ", sneg >> 2, "; on unsigned shifts in 0: ", uval >> 2);
    let k = 40;
    let m: u64 = 1 << k;             // a constant shifted by a variable count takes the destination type
    print("  1 << 40 as u64 = ", m);
    // There are no binary literals: write hex (0x..) or a shift instead.

    // ---------------------------------------------------------------
    // Memberwise math on fixed arrays and structs (no operator overloading)
    // ---------------------------------------------------------------
    let a = [1, 2, 3] + [10, 20, 30];           // elementwise: [11, 22, 33]
    print("memberwise array: ", a);
    let p = V2 { 1.0, 2.0 };
    let q = V2 { 0.5, 0.5 };
    var sum = p + q;                             // memberwise add of two structs
    sum *= 2;                                    // * and / also take one scalar operand
    print("memberwise struct: ", sum, "  -p = ", -p, "  p / 2.0 = ", p / 2.0);

    // ---------------------------------------------------------------
    // Reference identity: .==  .!=  (compare ADDRESSES; == compares values)
    // ---------------------------------------------------------------
    var xs = [7, 7];
    let r0 .= xs[0];                 // reference to xs[0]
    let r1b .= xs[1];                // reference to xs[1]
    print("identity: r0 == r1 (values) ", r0 == r1b, ", r0 .== r1 (same place) ", r0 .== r1b,
          ", r0 .!= r1 ", r0 .!= r1b, ", r0 .== xs[0] ", r0 .== xs[0]);

    // ---------------------------------------------------------------
    // Assignment operators: = .= += -= *= /= %= <<= >>= &= ^= |=  and ++ --
    // All of these are STATEMENTS, not expressions.
    // ---------------------------------------------------------------
    var v = 10;                      // =
    v += 5;  print("  += 5  -> ", v);
    v -= 3;  print("  -= 3  -> ", v);
    v *= 4;  print("  *= 4  -> ", v);
    v /= 6;  print("  /= 6  -> ", v);
    v %= 5;  print("  %= 5  -> ", v);
    v <<= 3; print("  <<= 3 -> ", v);
    v >>= 1; print("  >>= 1 -> ", v);
    v &= 6;  print("  &= 6  -> ", v);
    v ^= 3;  print("  ^= 3  -> ", v);
    v |= 8;  print("  |= 8  -> ", v);
    v++;     print("  ++    -> ", v);
    v--;     print("  --    -> ", v);
    var rr .= xs[0];                 // .= binds (or rebinds) a reference
    rr = 100;                        // = through the reference writes xs[0]
    rr .= xs[1];                     // rebind to xs[1]
    rr = 200;
    print("  .= rebinding: xs = ", xs);
    // let w = (v += 1);             // ERROR: assignments have no value

    // ---------------------------------------------------------------
    // No ternary ?: operator. `if` is an expression instead.
    // ---------------------------------------------------------------
    // let sign = x > 0 ? 1 : -1;    // ERROR: there is no ?: in Goose
    let sign = if x > 0 { 1 } else { -1 };
    print("if-expression instead of ?: -> ", sign);
}
