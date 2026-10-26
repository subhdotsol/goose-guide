import std;
import ffi;      // ffi::cstr(p) copies a C string the library owns (a u64 pointer) into Goose

// =====================================================================
// 27. Calling C / being called from C
// ---------------------------------------------------------------------
// Run from the goose-guide directory (the sidecar 27-calling-c.build sits
// beside this file and pulls in 27-calling-c/impl.c; a C compiler is needed
// to build that C, even for the in-process run):
//     ../oss/goose/build/goose 27-calling-c.goose
// or as an executable:
//     ../oss/goose/build/goose build 27-calling-c.goose -o /tmp/27-calling-c && /tmp/27-calling-c
//
// The "being called from C" half has its own runnable host in 27-calling-c/
// (exports.goose + host.c); the commands are at the bottom of this file.
// =====================================================================

// A flat, fixed-size struct: allowed to cross to C (by value or by pointer).
// Layout is Goose's PACKED layout: it matches C only if the fields already sit
// where C would put them. Here i32, i32, f64 = offsets 0, 4, 8 in both.
// (A u8 followed by an i32 would need `pad 3` written where C pads.)
struct Stats { lo: i32, hi: i32, mean: f64 }

// ---------------------------------------------------------------------
// extern fn — bind a Goose signature to a C function
// ---------------------------------------------------------------------
// No body. Top-level, fully typed, not generic. A call is a direct C call.
extern fn hypot(x: f64, y: f64) -> f64;           // C symbol with the SAME name (libm)
extern fn cube_root(x: f64) -> f64 = "cbrt";      // `= "name"`: a DIFFERENT C name (libm cbrt)
// (The older form `extern "cbrt" fn cube_root(...)` is deprecated: warning.)

// These come from our own 27-calling-c/impl.c, compiled via the sidecar.
extern fn crc32_bytes(s: const u8[:]) -> u32;     // a slice crosses as { data, len }
                                                  // `const` because C only reads it
extern fn fill(out: Stats&);                      // a struct filled through a pointer
extern fn stats_of(xs: const i32[:], out: Stats&);// slice in, struct pointer out
extern fn c_version(out: u8[>..]&);               // a BUILDER that C appends to
extern fn c_twice(x: i32) -> i32 = "impl_twice";  // renamed binding to our own C

// ---------------------------------------------------------------------
// extern "lib" { ... } — functions from a SHARED LIBRARY, by name
// ---------------------------------------------------------------------
// The library is opened with dlopen at startup and the symbols looked up; no
// C to compile or link. Members are extern fns without the `extern` keyword.
// "z" opens libz.dylib / libz.so / z.dll (zlib, present on macOS).
// Opaque pointers and memory the library owns come back as u64.
extern "z" {
    fn zlibVersion() -> u64;                      // returns a `const char *` -> u64
    fn zlib_crc32(crc: u64, buf: const u8&, len: u32) -> u64 = "crc32";  // renamed member
}

// The cheat sheet's SDL2 example. Only members a call REACHES are bound, and
// a library none of whose members is called is never opened — so declaring
// this is harmless even without SDL2 installed. (Calling SDL_Init would make
// the program fail at startup with "cannot open SDL2" here.)
extern "SDL2" {
    fn SDL_Init(flags: u32) -> i32;
    fn SDL_Quit();
    fn delay(ms: u32) = "SDL_Delay";              // Goose name `delay`, C name SDL_Delay
}

// ---------------------------------------------------------------------
// export fn — make a Goose function callable FROM C
// ---------------------------------------------------------------------
// The compiler emits a C wrapper under the Goose name or the given string.
// Must be top-level, non-generic, explicitly typed, at most one result; no
// defaults, `return ... from`, pool params or builders at the boundary.
// A `const u8[:]` result reaches C as a pointer plus an extra int64_t* length
// out-parameter (NOT NUL-terminated).
export fn hello() -> const u8[:] { return "Hello!" }      // C name: hello
export "c_add" fn add(a: i32, b: i32) -> i32 { a + b }    // C name: c_add
// Inside Goose they are ordinary functions you can call too.

fn main() {
    // -----------------------------------------------------------------
    // libm through extern fn
    // -----------------------------------------------------------------
    print("hypot(3, 4)      = ", hypot(3.0, 4.0));
    print("cube_root(27)    = ", cube_root(27.0));

    // -----------------------------------------------------------------
    // Our own C (impl.c)
    // -----------------------------------------------------------------
    // A string literal is const u8[:], passed as { data, len }.
    print("crc32_bytes(\"hello\") = ", crc32_bytes("hello"));    // 907060870 (0x3610a686)

    var s = Stats { 0, 0, 0.0 };
    fill(s);                                      // passed as a pointer: C writes into s
    print("after fill: ", s);

    let xs: i32[5] = [4, -2, 9, 1, 3];
    stats_of(xs[..], s);                          // a fixed array sliced to i32[:]
    print("stats_of([4,-2,9,1,3]): ", s);

    var ver: u8[>..] = [];
    ver.append("C says: ");
    c_version(ver);                               // C appends to our growable buffer
    print(ver);

    print("c_twice(21) = ", c_twice(21));

    // -----------------------------------------------------------------
    // A real shared library through extern "z" { ... }
    // -----------------------------------------------------------------
    // zlibVersion returns memory zlib owns -> u64; copy it with ffi::cstr.
    print("zlib version is non-empty: ", ffi::cstr(zlibVersion()).len > 0);
    // C wants (pointer, count): pass the first element by reference + the length.
    let msg = "hello";
    print("zlib crc32(\"hello\") = ", zlib_crc32(0, msg[0], msg.len as u32));  // same as ours
    // For a NUL-terminated C string, append "\0" yourself and pass text[0].

    // -----------------------------------------------------------------
    // Exported functions are still callable from Goose
    // -----------------------------------------------------------------
    print("hello() = ", hello(), ", add(20, 22) = ", add(20, 22));

    // -----------------------------------------------------------------
    // What may cross the boundary
    // -----------------------------------------------------------------
    // * scalars and bool (i32=int, u32=unsigned, i64=int64_t, f64=double,
    //   bool = 1 byte; a C enum/SDL_bool is an int -> declare it i32)
    // * flat fixed-size structs/arrays, by value (a struct with `pad`: by
    //   reference only)
    // * T&  -> a pointer;   T[:] -> { data, len };   u8[>..]& -> a builder
    // * opaque handles (SDL_Window*, FILE*, ...) are u64
    // Rejected at the declaration: varints, references inside structs,
    // variable/resizable values by value, optionals. E.g.:
    //   extern fn bad(x: i64?) -> i64;     // error: optional cannot cross
    // Callbacks and variadic C functions (printf) need a small C adapter.
    // C must not keep a borrowed argument beyond the call.
}

// =====================================================================
// Being called FROM C (a C host program)
// ---------------------------------------------------------------------
// See 27-calling-c/exports.goose and 27-calling-c/host.c. From goose-guide:
//
//   ../oss/goose/build/goose --standalone --header /tmp/exports.h \
//       -o /tmp/exports.c 27-calling-c/exports.goose
//   cc -I/tmp -o /tmp/host 27-calling-c/host.c /tmp/exports.c -lm && /tmp/host
//
// --standalone puts the whole runtime in the one C file; --header writes a
// header declaring goose_init(argc, argv) and the exported functions. The C
// host must call goose_init ONCE first: it sets up the runtime and globals
// and runs the Goose `main` (if any). Exported functions are not
// thread-safe: call them from the thread that called goose_init.
// =====================================================================
