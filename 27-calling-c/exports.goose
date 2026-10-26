// 27-calling-c/exports.goose — a Goose "library" called from a C host (host.c).
//
// Build the C for the host and link it (from goose-guide):
//   ../oss/goose/build/goose --standalone --header /tmp/exports.h \
//       -o /tmp/exports.c 27-calling-c/exports.goose
//   cc -I/tmp -o /tmp/host 27-calling-c/host.c /tmp/exports.c -lm && /tmp/host
//
// It is also a normal program: ../oss/goose/build/goose 27-calling-c/exports.goose
import std;

var calls: i64 = 0;                      // globals work: goose_init initializes them

// `export fn` -> a C function with the same name.
// A `const u8[:]` result becomes, in the generated header:
//     const uint8_t * hello(int64_t *gs_export_len);
// i.e. pointer + length out-parameter, NOT NUL-terminated.
export fn hello() -> const u8[:] { return "Hello from Goose!" }

// `export "name" fn` -> a C function under a chosen name.
export "c_add" fn add(a: i32, b: i32) -> i32 { calls += 1; a + b }

export fn call_count() -> i64 { calls }

// When hosted by C, goose_init(argc, argv) runs this main once: a library's
// start-up code goes here.
fn main() { print("[goose] main ran inside goose_init"); }
