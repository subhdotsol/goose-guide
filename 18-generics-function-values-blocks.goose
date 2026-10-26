import std;

// ===================================================================
// 18. Generics, function values, blocks
// ===================================================================
// Goose generics are MONOMORPHIZED: every distinct set of type arguments
// produces its own copy of the function, and each copy is type-checked
// separately. There are NO trait bounds / interfaces: if `a > b` makes
// sense for the concrete T, the instantiation compiles; otherwise that
// particular instantiation is a compile error.

// ---------------------------------------------------------------
// Generic functions: type parameters in <...> after the name
// ---------------------------------------------------------------
// `T` is inferred from the arguments at each call site.
// `-` and `>` must work on T; there's no bound saying so — each use is
// simply checked once T is known.
fn span<T>(a: T, b: T) -> T { if a > b { a - b } else { b - a } }

// When T does not appear in any parameter it cannot be inferred, so
// the caller must write it explicitly: zero<f64>().
// default<T>() is the builtin "zero value" of any type.
fn zero<T>() -> T { default<T>() }

// An untyped parameter (no `: Type`) is also generic: each call with a
// new argument type makes a new instantiation (see section 17).
fn twice(x) { x + x }

// ---------------------------------------------------------------
// Function values: a type parameter that is a FUNCTION
// ---------------------------------------------------------------
// `F` here is a compile-time parameter. Calling `F(i)` is a direct call
// to whatever function/block was passed in, so it can be inlined.
// There is no runtime function pointer involved.
fn each_step<F>(lo: i64, hi: i64, step: i64 = 1) {
    var i = lo;                       // loop counter
    while i < hi { F(i); i += step; } // call the passed-in function for each step
}

// `F: fn(i64)` is an OPTIONAL bound. It is documentation only: it says
// what shape of function is expected, but it does not change checking.
fn apply<F: fn(i64)>(a: i64) { F(a); }

// A named function we can pass as a function value.
fn show(v: i64) { print("  show: ", v); }

// A function value can also return a value; G's result is used here.
fn map_one<G>(x: i64) -> i64 { G(x) }
fn square(x: i64) -> i64 { x * x }

// A block parameter that takes two arguments.
fn combine<F>(a: i64, b: i64) -> i64 { F(a, b) }

// ---------------------------------------------------------------
// `return` inside a block returns from the ENCLOSING NAMED FUNCTION
// ---------------------------------------------------------------
// The block below is passed to each_step, but `return it;` does not
// just end the block — it returns from first_multiple_of_7 itself.
fn first_multiple_of_7(lo: i64, hi: i64) -> i64 {
    each_step(lo, hi, 3) { if it % 7 == 0 { return it; } };
    return -1;                        // reached only if no multiple was found
}

// ---------------------------------------------------------------
// "A call takes one trailing block; pass any others by name."
// ---------------------------------------------------------------
// This function takes TWO function values. Only one can be written as a
// trailing block at the call site; the other must be a named function.
fn transform_then<Pre, Post>(x: i64) { Post(Pre(x)); }
fn add_ten(x: i64) -> i64 { x + 10 }

fn main() {
    // ---------------------------------------------------------------
    // Calling generics
    // ---------------------------------------------------------------
    print("span(3, 10)     = ", span(3, 10));        // T inferred as i64
    print("span(2.5, 1.0)  = ", span(2.5, 1.0));     // T inferred as f64: a 2nd instantiation
    let z = zero<f64>();                              // T can't be inferred -> write it explicitly
    let zi = zero<i32>();                             // another instantiation, for i32
    print("zero<f64>()     = ", z);
    print("zero<i32>()     = ", zi);
    print("twice(21)       = ", twice(21));          // untyped param: instantiated for i64
    print("twice(1.25)     = ", twice(1.25));        // ...and again for f64
    // span(true, false);  // ERROR: no `>`/`-` on bool. Without trait bounds,
    //                     // the error appears only when this instantiation is checked.

    // ---------------------------------------------------------------
    // Trailing blocks
    // ---------------------------------------------------------------
    // A `{ ... }` written after the call's `( )` is passed as the LAST
    // function-value type parameter (F here). Inside the block, the
    // single parameter is available implicitly as `it`.
    // A trailing-block call used as a STATEMENT must end with `;`.
    print("each_step(0, 10, 3) with `it`:");
    each_step(0, 10, 3) { print("  it = ", it); };

    // Name the block's parameter with `name =>` instead of using `it`.
    // Also note: step uses its default value (1) here.
    print("each_step(0, 3) with a named parameter `i`:");
    each_step(0, 3) { i => print("  i = ", i); };

    // Pass a NAMED function as a function value (no trailing block).
    print("apply(5, show):");
    apply(5, show);

    // Function values that return a result.
    print("map_one(7, square) = ", map_one(7, square));       // named function
    print("map_one(7) { it + 1 } = ", map_one(7) { it + 1 }); // block: last expr is the result

    // A block with two named parameters: `a, b => ...`.
    print("combine(6, 7) { a, b => a * b } = ", combine(6, 7) { a, b => a * b });

    // Two function values: one by name (add_ten), one as trailing block.
    print("transform_then(5, add_ten) { print(it) }:");
    transform_then(5, add_ten) { print("  result: ", it); };

    // `return` inside a block exits the enclosing named function.
    print("first_multiple_of_7(1, 30) = ", first_multiple_of_7(1, 30)); // 1,4,7 -> 7
    print("first_multiple_of_7(1, 5)  = ", first_multiple_of_7(1, 5));  // none -> -1

    // Blocks can read and write locals of the surrounding function.
    var acc = 0;                                // a local in main
    each_step(1, 5) { acc += it; };             // the block updates it directly: 1+2+3+4
    print("acc after block = ", acc);

    // ---------------------------------------------------------------
    // Common std patterns that take blocks
    // ---------------------------------------------------------------
    var xs: i64[>..] = [5, 12, 3, 8, 20, 7];     // a growable array to play with
    let evens = xs.filter() { it % 2 == 0 };     // keep elements where the block is true
    print("filter evens  = ", evens);
    let total = fold(xs, 0) { acc2, x => acc2 + x }; // reduce: block gets (accumulator, element)
    print("fold sum      = ", total);
    let doubled = xs.map() { it * 2 };           // new array of block results
    print("map doubled   = ", doubled);
    let big = xs.find() { it > 10 };             // first element matching the block
    print("find > 10     = ", big);
    sort(xs) { a, b => a > b };                  // sort in place; block = "a goes before b"
    print("sort desc     = ", xs);              // (statement form: note the trailing `;`)

    // ---------------------------------------------------------------
    // What function values CANNOT do (all compile errors)
    // ---------------------------------------------------------------
    // There are no closures and no function pointers. A function value is
    // only a compile-time type parameter, so it cannot be:
    //   let f = show;                 // ERROR: cannot store a function value
    //   struct S { cb: fn(i64) }      // ERROR: cannot put it in data
    //   fn get() { return show; }     // ERROR: cannot return it
    print("done");
}
