// ===================================================================
// 07 - Casts and conversions (syntax.md section 7)
// ===================================================================
// Rule of thumb: a conversion the compiler can PROVE keeps the value is
// implicit; anything that could lose bits or flip a sign needs a cast.
//   x as T   - range-checked in --debug builds (aborts if the value changes),
//              silently truncates/wraps/rounds toward zero in release builds
//   x as! T  - NEVER checked, not even in --debug: deliberate truncation
// Conversions TO a float are never checked, in either form.
// ===================================================================
import std;

fn takes_i64(v: i64) -> i64 { v }    // used to show implicit widening at a call
fn takes_f64(v: f64) -> f64 { v }

fn main() {
    // ---------------------------------------------------------------
    // The cheat-sheet examples
    // ---------------------------------------------------------------
    let x = 300;                     // an i64
    // let a = x as u8;              // checked cast. 300 does NOT fit a u8, so under --debug
                                     // this aborts ("value changed"); in a release build it
                                     // silently truncates to 44. Commented out so this file
                                     // runs cleanly in BOTH build modes.
    let a = (x - 100) as u8;         // checked cast of 200: fits, so it never aborts
    let b = x as! u8;                // unchecked: deliberate truncation, 300 mod 256 = 44
    let c = 2.7 as! i64;             // float -> int truncates toward zero: 2
                                     // NOTE: the cheat sheet writes `2.7 as i64`. That gives 2 in
                                     // release, but `as` is CHECKED under --debug and aborts with
                                     // "as conversion changes the value" because .7 is lost.
                                     // Use `as!` when dropping the fraction is intended.
    let d = 5 as u32;                // fix a literal's type: d is a u32 (not the default i64)
    print("(x - 100) as u8: ", a, "  as! u8: ", b, "  2.7 as! i64: ", c, "  5 as u32: ", d);


    // ---------------------------------------------------------------
    // Float -> int is fully defined: truncate toward zero, then wrap into
    // the target width. NaN gives 0.
    // ---------------------------------------------------------------
    let neg_f = -2.7;
    let zero = 0.0;
    let nan = zero / zero;           // 0.0 / 0.0 is NaN
    // (`as!` again: under --debug, `as` aborts on a lost fraction or on NaN.)
    print("-2.7 as! i64: ", neg_f as! i64, "   NaN as! i64: ", nan as! i64, "   4.0 as i64: ", 4.0 as i64);

    // ---------------------------------------------------------------
    // IMPLICIT conversions (no cast needed)
    // ---------------------------------------------------------------
    // 1) same-signedness widening: i8 -> i32, u16 -> u64, ...
    let s8: i8 = -5;
    let s32: i32 = s8;               // i8 widens to i32
    let u16v: u16 = 60000;
    let u64v: u64 = u16v;            // u16 widens to u64
    print("same-sign widening: ", s32, " ", u64v);

    // 2) unsigned -> STRICTLY wider signed: u8 -> i16, u32 -> i64
    let ub: u8 = 255;
    let si16: i16 = ub;              // every u8 fits in an i16
    let u32v: u32 = 4000000000;
    print("unsigned -> wider signed: ", si16, " ", takes_i64(u32v));   // u32 -> i64 at a call

    // 3) f32 -> f64
    let f32v: f32 = 1.25;
    let f64v: f64 = f32v;
    print("f32 -> f64: ", f64v);

    // 4) any integer (u64 included) -> float, rounding to the nearest float
    let i: i64 = 7;
    let big: u64 = 18446744073709551615;
    print("int -> float: ", takes_f64(i), " ", takes_f64(big));

    // 5) literals into any type that holds them
    let lit8: u8 = 255;              // fits
    let litf: f32 = 3;               // an integer literal into a float
    print("literals: ", lit8, " ", litf);
    // let nope: u8 = 256;           // ERROR: constant 256 does not fit u8

    // ---------------------------------------------------------------
    // EXPLICIT `as` / `as!` needed for:
    // ---------------------------------------------------------------
    // narrowing
    let wide: i64 = 100;
    // let n8: i8 = wide;            // ERROR: i64 -> i8 is narrowing
    let n8: i8 = wide as i8;         // 100 fits, so the checked cast is fine
    // sign changes (same width, or signed -> unsigned)
    let minus1 = -1;
    // let u: u32 = minus1;          // ERROR: signed -> unsigned
    let u = minus1 as! u32;          // reinterpret the bits on purpose: 4294967295
    let ui: u32 = 7;
    let si: i32 = ui as i32;         // same-width u32 -> i32 also needs a cast
    // u64 -> signed (there is no wider signed type for u64 to go into)
    let u64small: u64 = 12;
    let back: i64 = u64small as i64;
    // f64 -> f32
    let precise = 0.1;
    // let lossy: f32 = precise;     // ERROR: f64 to f32 requires an explicit `as f32`
    let lossy = precise as f32;
    // float -> int
    let pi = 3.99;
    // let whole: i64 = pi;          // ERROR: float -> int always needs a cast
    let whole = pi as! i64;          // truncates toward zero: 3 (`as!`: losing .99 is intended)
    print("explicit: ", n8, " ", u, " ", si, " ", back, " ", lossy, " ", whole);

    // ---------------------------------------------------------------
    // `as` binds TIGHTEST (it is a postfix operator):
    //   a as i64 + b   means   (a as i64) + b
    // ---------------------------------------------------------------
    let pa: i32 = 2000000000;
    let pb: i32 = 2000000000;
    let prod = pa as i64 * pb;       // (pa as i64) * pb: an i64 multiply, no i32 overflow
    print("as binds tightest: ", prod);
    let fx = 7;
    let ratio = fx as f64 / 2;       // (fx as f64) / 2 = 3.5, not integer 7 / 2 = 3
    print("int division vs cast first: ", fx / 2, " vs ", ratio);

    // ---------------------------------------------------------------
    // A REDUNDANT cast is a WARNING (the compiler says the conversion is
    // already implicit), so this file keeps it commented out:
    //   let small: u8 = 9;
    //   let wide: i64 = 5;
    //   let q = small as i64 + wide;      // warning: redundant `as i64`: a u8
    //                                     // converts to i64 implicitly here
    // (But `small as i64 + 1000000` is NOT redundant: without the cast the
    //  literal would adapt to u8 and fail to fit, so the cast decides the width.)
    // A cast that DECIDES something (a literal's type, the width of an
    // operation, how a float rounds) gives no warning, like the ones above.
    // ---------------------------------------------------------------
}
