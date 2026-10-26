import std;

// =====================================================================
// 28. Function qualifiers
//
// A qualifier is a keyword written BEFORE `fn` (or instead of `fn`, for
// `thread_fn`) that changes how the compiler treats a function.
//
// The order is FIXED (writing them in another order is a parse error):
//
//     export / extern  ->  checkfree  ->  simd  ->  inline  ->  recursive  ->  fn / thread_fn
//
// | Qualifier      | Meaning                                                   |
// |----------------|-----------------------------------------------------------|
// | recursive fn   | the entry of a recursive cycle                            |
// | inline fn      | always inlined                                            |
// | simd fn        | built in baseline, AVX2 and AVX-512 versions, picked at runtime |
// | checkfree fn   | no bounds check may remain                                |
// | thread_fn      | a worker entry point                                      |
// | extern fn      | a C function                                              |
// | export fn      | a Goose function callable from C                          |
//
// None of inline / simd / checkfree changes WHAT a program computes;
// they only change how it is built (or are checked promises).
// =====================================================================

// ---------------------------------------------------------------------
// `recursive fn`: the ENTRY of a recursive cycle
// Recursion is opt-in. A function that (directly or indirectly) calls
// itself without the qualifier is a compile error. Every function in the
// cycle needs a fully explicit signature (parameter AND return types).
// ---------------------------------------------------------------------
recursive fn factorial(n: i64) -> i64 {      // calls itself: must be `recursive`
    if n <= 1 { 1 } else { n * factorial(n - 1) }  // last expression is the result
}

// A cycle of two functions: only the ENTRY (`is_even`) carries the qualifier.
recursive fn is_even(n: i64) -> bool {        // entry of the even/odd cycle
    if n == 0 { true } else { is_odd(n - 1) }  // calls into the other half of the cycle
}
fn is_odd(n: i64) -> bool {                   // a plain fn, but still part of the cycle
    if n == 0 { false } else { is_even(n - 1) } // calls back to the entry
}

// Key rule (reference section 19): no function in the cycle may call back
// into the cycle while one of its growable/variable-size locals is in
// scope. Growable scratch must live in a block that ends before the call,
// or be passed in by reference.
// recursive fn bad(n: i64) -> i64 {
//     var tmp: i64[>..] = [];               // growable local still in scope...
//     if n == 0 { 0 } else { bad(n - 1) }   // ...at the recursive call: compile error
// }

// ---------------------------------------------------------------------
// `inline fn`: always inlined at every call, whatever its size.
// Without it the compiler decides from the function's size and call count.
// Cannot be combined with extern, export, simd, recursive or thread_fn.
// ---------------------------------------------------------------------
inline fn clamp01(x: f32) -> f32 {            // the cheat-sheet example
    if x < 0 { 0 } else if x > 1 { 1 } else { x } // if/else is an expression
}
// inline recursive fn nope(n: i64) -> i64 { ... }   // error: inline + recursive not allowed

// ---------------------------------------------------------------------
// `simd fn`: built once for the baseline CPU and once more for each wider
// instruction set (AVX2, AVX-512 on x86-64); the widest the CPU supports
// is chosen at each call. Good for hot loops the C compiler can vectorize.
// Every version computes exactly the same result. A backend may ignore it
// (the in-process TinyCC backend used by `goose file.goose` does).
// ---------------------------------------------------------------------
simd fn checksum(xs: u8[:]) -> u32 {          // the cheat-sheet example
    var h: u32 = 0;                           // running hash, explicit u32
    for x in xs { h += x as u32 * 31 + 7; }   // `as` widens each byte to u32
    h                                         // trailing expression = return value
}

// ---------------------------------------------------------------------
// `checkfree fn`: the compiler must PROVE every bounds check away; if any
// check remains (after bounds-check elimination, in every specialization
// and inlined copy) the program is rejected. Calls inside it may only go to
// other checkfree functions, builtins, or extern fns.
// Other aborts (like `assert`) are allowed - use them to state preconditions
// once, outside the loop, so the loop itself is check-free.
// ---------------------------------------------------------------------
var nodes: i32[>..] = [];                     // a global array
type NodeId = u32 in nodes;                   // an index type: always a valid index of `nodes`

checkfree fn sum_at(ids: NodeId[:], weights: i32[>..]&) -> i64 {
    assert(weights.len >= nodes.len);         // precondition stated ONCE
    var t = 0;                                // i64 accumulator (literal default)
    for id in ids {                           // id has type NodeId
        t += nodes[id] + weights[id];         // both indexes proven in range: no check left
    }
    return t;
}

// Qualifiers combine, in the fixed order: checkfree comes before simd.
checkfree simd fn total(xs: i64[:]) -> i64 {  // `for x in xs` needs no bounds check
    var t = 0;
    for x in xs { t += x; }
    t
}
// simd checkfree fn wrong(...)               // error: wrong qualifier order

// checkfree fn risky(xs: i64[:], i: i64) -> i64 { xs[i] }
//     // error: the check on xs[i] cannot be proven away (i is arbitrary)

// ---------------------------------------------------------------------
// `extern fn`: a declaration WITHOUT a body binding a Goose signature to a
// C function. A string after `=` is the C symbol; otherwise the Goose name
// is used. Top-level, fully typed, not generic. Only C-shaped types cross:
// scalars, bool, flat fixed-size structs, T& (pointer), T[:] (data+len),
// u8[>..]& (builder).
// ---------------------------------------------------------------------
extern fn cube_root(x: f64) -> f64 = "cbrt";  // libm's cbrt under a Goose name
extern fn hypot(x: f64, y: f64) -> f64;       // C symbol is the same name: hypot
// extern "cbrt" fn old(x: f64) -> f64;       // older form: deprecated, gives a warning

// ---------------------------------------------------------------------
// `export fn`: a Goose function callable from C. The compiler emits a C
// wrapper under the function's name, or under the string given:
// `export "sym" fn`. Top-level, non-generic, explicit parameter types,
// at most one typed result. It is still an ordinary Goose function too.
// (Build for a C host with: goose --standalone --header h.h -o h.c file.goose)
// ---------------------------------------------------------------------
export fn hello_world() -> const u8[:] { return "Hello, world!" } // C name: hello_world
export "c_add" fn add(a: i32, b: i32) -> i32 { a + b }              // C name: c_add

// ---------------------------------------------------------------------
// `thread_fn`: a worker entry point (used INSTEAD of `fn`). It and all it
// calls are compiled as a separate program with its own copies of globals.
// Its parameters must be flat and have no defaults.
//
// NOT runnable here: the in-process JIT (`goose file.goose`) aborts with
// "JIT mode does not support threads yet". Build with `goose build` to try:
//
// struct Job { n: i32 }
// thread_fn doubler(k: i32) {                // worker entry; spawned, never called directly
//     let j = qget<Job>();                    // receive from the Job queue
//     qput(Job { n: j.n * 2 + k });           // send a result back
// }
// // in main:
// //   qput(Job { n: 20 });
// //   let id = thread_spawn(doubler, 2);
// //   thread_wait(id);
// //   print(qget<Job>().n);                  // 42
// ---------------------------------------------------------------------

fn main() {
    // recursive
    print("factorial(10) = ", factorial(10));          // 3628800
    print("is_even(10) = ", is_even(10), ", is_even(7) = ", is_even(7));

    // inline: behaves exactly like a normal call
    print("clamp01(-0.5) = ", clamp01(-0.5), ", clamp01(0.25) = ", clamp01(0.25),
          ", clamp01(1.5) = ", clamp01(1.5));

    // simd: same result whatever version runs
    print("checksum(\"goose\") = ", checksum("goose"));  // 16806

    // checkfree
    for w in [1, 2, 3] { nodes.push(w as i32); }       // nodes = [1, 2, 3]
    var weights: i32[>..] = [10, 20, 30];
    let ids: NodeId[2] = [2 as NodeId, 0 as NodeId];   // `as` makes plain ints into NodeIds
    print("sum_at = ", sum_at(ids, weights));          // (3+30) + (1+10) = 44
    let xs: i64[4] = [1, 2, 3, 4];
    print("total = ", total(xs));                      // checkfree simd: 10

    // extern: calls straight into libm
    print("cube_root(27) = ", cube_root(27.0), ", hypot(3, 4) = ", hypot(3.0, 4.0));

    // export: callable from Goose too
    print("hello_world() = ", hello_world(), ", add(20, 22) = ", add(20, 22));
}
