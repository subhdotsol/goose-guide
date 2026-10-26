import std;

// =====================================================================
// 17. Functions
//
// - Free functions only: no methods, no `impl`, no classes.
// - UFCS: `x.f(a)` is the same as `f(x, a)` (works on literals too).
// - No named arguments; only TRAILING parameters with defaults can be omitted.
// - The result type may be omitted (inferred), but must be written for
//   recursive functions.
// - Top-level declarations are order-independent.
// =====================================================================

// ---------------------------------------------------------------
// Basic forms
// ---------------------------------------------------------------
fn add(a: i64, b: i64) -> i64 { a + b }           // the LAST expression (no `;`) is the result
fn add2(a: i64, b: i64) -> i64 { return a + b; }  // or use an explicit `return`
fn greet() { print("hi from greet()"); }          // no `->`: no result
fn twice(x) { x + x }                             // untyped parameter = GENERIC (specialized per call type)

// Trailing defaults: scaled(2) means scaled(2, 0, 1.0).
// The i32 sum is implicitly widened to f32 when multiplied by c.
fn scaled(a: i32, b: i32 = 0, c: f32 = 1.0) -> f32 { (a + b) * c }

// Parameters are `let` bindings. A `var` parameter is a reassignable local COPY.
fn bump(var n: i64) -> i64 { n += 1; n }          // the caller's value is not affected
// fn bad(n: i64) { n += 1; }                     // ERROR: "cannot assign to let n": a plain parameter is a let

// Reference parameter: writes the caller's variable (pass an lvalue, no `&`).
fn inc(n: i64&) { n += 1; }

// Slice parameter `T[:]`: accepts every array kind (fixed, growable, literal, sub-slice).
// (named `sum_of` here because std already has a generic `sum`, and the two
// would make `sum(xs)` an ambiguous call)
fn sum_of(xs: i64[:]) -> i64 { var t = 0; for x in xs { t += x; } t }

// Omitted result type: inferred from the body's final expression.
fn average(xs: i64[:]) { (sum_of(xs) as f64) / xs.len }   // xs.len (i64) widens to f64 implicitly

// A recursive function must spell out its result type (and needs `recursive`).
recursive fn fact(n: i64) -> i64 { if n <= 1 { 1 } else { n * fact(n - 1) } }
// recursive fn fact(n: i64) { ... }   // ERROR without `-> i64`: the recursive call's type is unknown (void)
// fn fact(n: i64) -> i64 { ... }       // ERROR without `recursive`: "recursive call cycle ... not declared `recursive fn`"

// ---------------------------------------------------------------
// Multiple results: a CALLING CONVENTION, not a tuple
// ---------------------------------------------------------------
fn divide(a: i64, b: i64) -> i64, bool {
    if b == 0 { return 0, false; }    // each branch must `return` both values
    return a / b, true;
}

// `return f()` forwards ALL results of f.
fn divide_by_two(a: i64) -> i64, bool { return divide(a, 2); }

// ---------------------------------------------------------------
// UFCS helper (with defaults, to show it on a literal)
// ---------------------------------------------------------------
fn limit(x: i64, lo: i64 = 0, hi: i64 = 100) -> i64 {
    if x < lo { lo } else if x > hi { hi } else { x }
}

// ---------------------------------------------------------------
// Overloading: resolved statically by PARAMETER types.
// The expected RESULT type never selects an overload.
// ---------------------------------------------------------------
fn describe(x: i64) -> u8[>..] { str("int ", x) }
fn describe(x: f64) -> u8[>..] { str("float ", x) }
fn describe(xs: i64[:]) -> u8[>..] { str(xs.len, " ints") }
// fn describe(x: i64) -> f64 { 0.0 } // ERROR at the call: "ambiguous call to describe": the result type can't disambiguate

fn main() {
    // ---------------------------------------------------------------
    // Calling the basic forms
    // ---------------------------------------------------------------
    print("add(2, 3) = ", add(2, 3), ", add2(2, 3) = ", add2(2, 3));
    greet();
    print("twice(21) = ", twice(21), ", twice(1.25) = ", twice(1.25));  // one generic, two specializations

    // Defaults: omit any number of TRAILING parameters.
    print("scaled(2) = ", scaled(2), ", scaled(2, 3) = ", scaled(2, 3), ", scaled(2, 3, 0.5) = ", scaled(2, 3, 0.5));
    // scaled(2, c: 0.5);             // ERROR: no named arguments; you can't skip b to set c

    let start = 10;
    print("bump(start) = ", bump(start), ", start still = ", start);   // var param: a local copy

    var count = 0;
    inc(count);                       // binds count by reference
    inc(count);
    print("count after inc twice: ", count);

    let fixed: i64[3] = [1, 2, 3];
    var grow: i64[>..] = [4, 5];
    print("sum_of(fixed) = ", sum_of(fixed), ", sum_of(grow) = ", sum_of(grow), ", sum_of([7, 8]) = ", sum_of([7, 8]),
          ", sum_of(fixed[1..]) = ", sum_of(fixed[1..]));   // every array kind passes as a slice

    print("average(fixed) (inferred f64 result) = ", average(fixed));
    print("fact(5) (recursive, result type written) = ", fact(5));

    // ---------------------------------------------------------------
    // Multiple results
    // ---------------------------------------------------------------
    let q, ok = divide(7, 2);         // bind both results
    print("divide(7, 2) -> q = ", q, ", ok = ", ok);

    var r = 0; var f = true;
    r, f = divide(1, 0);              // assign to EXISTING places
    print("divide(1, 0) -> r = ", r, ", f = ", f);

    let only_q = divide(9, 3);        // a value context takes the FIRST result only
    print("only_q = divide(9, 3) = ", only_q);

    let h, hok = divide_by_two(11);   // forwarded both results
    print("divide_by_two(11) -> ", h, ", ", hok);

    // ---------------------------------------------------------------
    // UFCS: x.f(a) == f(x, a), including on literals
    // ---------------------------------------------------------------
    print("limit(250) = ", limit(250), ", 250.limit() = ", 250.limit());
    print("7.limit(0, 5) = ", 7.limit(0, 5), ", (-5).limit(-10) = ", (-5).limit(-10));
    print("grow.sum_of() = ", grow.sum_of(), ", 3.twice() = ", 3.twice());

    // ---------------------------------------------------------------
    // Overloading by parameter type
    // ---------------------------------------------------------------
    print(describe(7), "; ", describe(2.5), "; ", fixed.describe(), "; ", 2.5.describe());

    // ---------------------------------------------------------------
    // Nested functions read AND write the enclosing function's locals
    // ---------------------------------------------------------------
    var total = 0;
    fn add_to_total(v: i64) { total += v; }   // writes main's `total`
    add_to_total(3);
    add_to_total(4);
    print("total after nested add_to_total(3), (4): ", total);   // 7
    // The enclosing code may call a nested function only AFTER its declaration.
}
